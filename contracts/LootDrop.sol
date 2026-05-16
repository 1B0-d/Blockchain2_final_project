// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { GameItems } from "./GameItems.sol";

/// @title IVRFCoordinatorV2Plus
/// @notice Minimal interface — matches Chainlink VRF V2+ on-chain signature.
interface IVRFCoordinatorV2Plus {
    function requestRandomWords(
        bytes32 keyHash,
        uint256 subId,
        uint16  minimumRequestConfirmations,
        uint32  callbackGasLimit,
        uint32  numWords,
        bytes   calldata extraArgs
    ) external returns (uint256 requestId);
}

/// @title LootDrop
/// @notice Pays a fee and receives a random ERC1155 loot item via Chainlink VRF.
///
///         On mainnet / testnets that have VRF: deploy with `useRealVRF = true`
///         and provide a funded subscription.
///
///         In tests: deploy with `useRealVRF = false`; the contract uses a
///         pseudo-random fallback so tests don't need a VRF coordinator mock.
///
///         Drop rates are stored as cumulative weights; governance can update
///         them via `setDropTable`.
contract LootDrop is AccessControl, ReentrancyGuard {
    // ───────────────────────── roles ─────────────────────────────────────────
    bytes32 public constant DROP_MANAGER_ROLE = keccak256("DROP_MANAGER_ROLE");

    // ───────────────────────── VRF config ────────────────────────────────────
    IVRFCoordinatorV2Plus public immutable vrfCoordinator;
    bytes32 public immutable keyHash;
    uint256 public immutable subscriptionId;
    uint16  public constant  REQUEST_CONFIRMATIONS = 3;
    uint32  public constant  CALLBACK_GAS_LIMIT    = 200_000;
    bool    public immutable useRealVRF;

    // ───────────────────────── loot state ────────────────────────────────────
    GameItems public immutable items;

    struct LootEntry {
        uint256 itemId;
        uint256 weight;      // relative weight; higher = more common
    }

    LootEntry[] public dropTable;
    uint256     public totalWeight;

    /// @notice Cost in ETH to open a loot box (sent to feeReceiver).
    uint256 public lootFee;
    address public feeReceiver;

    /// @notice Pending VRF requests: requestId => opener.
    mapping(uint256 => address) public pendingRequests;

    // ───────────────────────── events ────────────────────────────────────────
    event LootRequested(address indexed player, uint256 indexed requestId);
    event LootDropped(address indexed player, uint256 indexed itemId, uint256 randomWord);
    event DropTableUpdated(uint256 entriesCount, uint256 newTotalWeight);
    event LootFeeUpdated(uint256 oldFee, uint256 newFee);

    // ───────────────────────── errors ────────────────────────────────────────
    error DropTableEmpty();
    error InsufficientFee(uint256 sent, uint256 required);
    error RequestNotFound(uint256 requestId);
    error OnlyVRFCoordinator();

    // ───────────────────────── constructor ───────────────────────────────────
    /// @param _vrfCoordinator Address of Chainlink VRF coordinator (or address(0) for mock mode).
    /// @param _keyHash        VRF key hash (lane).
    /// @param _subscriptionId Chainlink subscription ID (ignored in mock mode).
    /// @param _useRealVRF     If false, uses a pseudo-random fallback (tests only).
    constructor(
        address _items,
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint256 _subscriptionId,
        bool    _useRealVRF,
        uint256 _lootFee,
        address _feeReceiver,
        address _admin
    ) {
        require(_items != address(0), "LootDrop: zero items");
        require(_feeReceiver != address(0), "LootDrop: zero feeReceiver");
        require(_admin != address(0), "LootDrop: zero admin");

        items          = GameItems(_items);
        vrfCoordinator = IVRFCoordinatorV2Plus(_vrfCoordinator);
        keyHash        = _keyHash;
        subscriptionId = _subscriptionId;
        useRealVRF     = _useRealVRF;
        lootFee        = _lootFee;
        feeReceiver    = _feeReceiver;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(DROP_MANAGER_ROLE, _admin);
    }

    // ───────────────────────── player action ─────────────────────────────────

    /// @notice Pay the loot fee and request a random item.
    ///         In real VRF mode:  emits LootRequested; item delivered in fulfillment callback.
    ///         In mock mode:      item is delivered synchronously in the same call.
    function openLootBox() external payable nonReentrant {
        if (dropTable.length == 0) revert DropTableEmpty();
        if (msg.value < lootFee) revert InsufficientFee(msg.value, lootFee);

        // Forward fee
        if (lootFee > 0) {
            (bool ok,) = feeReceiver.call{ value: lootFee }("");
            require(ok, "LootDrop: fee transfer failed");
        }
        // Refund excess
        if (msg.value > lootFee) {
            (bool ok2,) = msg.sender.call{ value: msg.value - lootFee }("");
            require(ok2, "LootDrop: refund failed");
        }

        if (useRealVRF) {
            // Request randomness from Chainlink VRF V2+
            uint256 requestId = vrfCoordinator.requestRandomWords(
                keyHash,
                subscriptionId,
                REQUEST_CONFIRMATIONS,
                CALLBACK_GAS_LIMIT,
                1, // numWords
                "" // no extra args
            );
            pendingRequests[requestId] = msg.sender;
            emit LootRequested(msg.sender, requestId);
        } else {
            // ── Mock VRF: pseudo-random inline fulfillment (tests / local) ──
            uint256 mockRandom = uint256(
                keccak256(abi.encodePacked(block.prevrandao, block.timestamp, msg.sender, gasleft()))
            );
            _deliverLoot(msg.sender, mockRandom);
        }
    }

    /// @notice Chainlink VRF coordinator calls this after randomness is ready.
    /// @dev    Only callable by the VRF coordinator (enforced via `useRealVRF`).
    function rawFulfillRandomWords(uint256 requestId, uint256[] calldata randomWords)
        external
    {
        if (!useRealVRF) revert OnlyVRFCoordinator();
        if (msg.sender != address(vrfCoordinator)) revert OnlyVRFCoordinator();

        address player = pendingRequests[requestId];
        if (player == address(0)) revert RequestNotFound(requestId);
        delete pendingRequests[requestId];

        _deliverLoot(player, randomWords[0]);
    }

    // ───────────────────────── governance ────────────────────────────────────

    /// @notice Replace the entire drop table (governance-controlled drop rates).
    function setDropTable(LootEntry[] calldata entries)
        external
        onlyRole(DROP_MANAGER_ROLE)
    {
        require(entries.length > 0, "LootDrop: empty table");

        delete dropTable;
        uint256 total;
        for (uint256 i; i < entries.length; ++i) {
            require(entries[i].weight > 0, "LootDrop: zero weight");
            dropTable.push(entries[i]);
            total += entries[i].weight;
        }
        totalWeight = total;
        emit DropTableUpdated(entries.length, total);
    }

    function setLootFee(uint256 newFee) external onlyRole(DROP_MANAGER_ROLE) {
        emit LootFeeUpdated(lootFee, newFee);
        lootFee = newFee;
    }

    function setFeeReceiver(address newReceiver) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newReceiver != address(0), "LootDrop: zero receiver");
        feeReceiver = newReceiver;
    }

    // ───────────────────────── internal ──────────────────────────────────────

    function _deliverLoot(address player, uint256 randomWord) internal {
        uint256 roll = randomWord % totalWeight;
        uint256 cumulative;
        uint256 wonItemId;

        for (uint256 i; i < dropTable.length; ++i) {
            cumulative += dropTable[i].weight;
            if (roll < cumulative) {
                wonItemId = dropTable[i].itemId;
                break;
            }
        }

        items.mint(player, wonItemId, 1, "");
        emit LootDropped(player, wonItemId, randomWord);
    }

    // ───────────────────────── receive ETH ───────────────────────────────────
    receive() external payable {}
}
