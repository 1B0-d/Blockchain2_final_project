// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { GameItems } from "./GameItems.sol";

/// @title RentalVault
/// @notice Lend rare ERC1155 items for a fixed duration in exchange for a fee paid in ETH.
///
/// Flow:
///   1. Owner deposits item → `listItem`
///   2. Renter pays fee → `rentItem` (item transferred to renter for duration)
///   3. After expiry, anyone calls `reclaimItem` → item returned to lender
///
/// @dev Uses AccessControl for admin functions. Rental fee is configurable by governance.
contract RentalVault is AccessControl, ReentrancyGuard, IERC1155Receiver {
    // ───────────────────────── roles ─────────────────────────────────────────
    bytes32 public constant VAULT_MANAGER_ROLE = keccak256("VAULT_MANAGER_ROLE");

    // ───────────────────────── types ─────────────────────────────────────────
    struct Listing {
        address lender;
        uint256 itemId;
        uint256 amount;
        uint256 pricePerPeriod; // ETH per `rentalPeriod` seconds
        bool    rented;
        address renter;
        uint256 rentalEnd;      // block.timestamp when rental expires
    }

    // ───────────────────────── state ─────────────────────────────────────────
    GameItems public immutable items;

    /// @notice Duration of a single rental period in seconds (governance-settable).
    uint256 public rentalPeriod;

    /// @notice Protocol fee taken from each rental in bps.
    uint256 public protocolFeeBps;
    address public feeReceiver;

    mapping(uint256 => Listing) private _listings;
    uint256 public nextListingId;

    // ───────────────────────── events ────────────────────────────────────────
    event ItemListed(
        uint256 indexed listingId,
        address indexed lender,
        uint256 indexed itemId,
        uint256 amount,
        uint256 pricePerPeriod
    );
    event ItemRented(
        uint256 indexed listingId,
        address indexed renter,
        uint256 rentalEnd,
        uint256 feePaid
    );
    event ItemReclaimed(uint256 indexed listingId, address indexed lender);
    event ListingCancelled(uint256 indexed listingId);
    event RentalPeriodUpdated(uint256 oldPeriod, uint256 newPeriod);
    event ProtocolFeeUpdated(uint256 oldFee, uint256 newFee);

    // ───────────────────────── errors ────────────────────────────────────────
    error ListingNotFound(uint256 listingId);
    error AlreadyRented(uint256 listingId);
    error NotRented(uint256 listingId);
    error RentalNotExpired(uint256 listingId, uint256 expiresAt);
    error NotLender(uint256 listingId);
    error InsufficientPayment(uint256 sent, uint256 required);
    error InvalidFee();

    // ───────────────────────── constructor ───────────────────────────────────
    constructor(
        address _items,
        uint256 _rentalPeriod,
        uint256 _protocolFeeBps,
        address _feeReceiver,
        address _admin
    ) {
        require(_items != address(0), "RentalVault: zero items");
        require(_feeReceiver != address(0), "RentalVault: zero feeReceiver");
        require(_admin != address(0), "RentalVault: zero admin");
        require(_protocolFeeBps <= 2_000, "RentalVault: fee too high"); // max 20%

        items            = GameItems(_items);
        rentalPeriod     = _rentalPeriod;
        protocolFeeBps   = _protocolFeeBps;
        feeReceiver      = _feeReceiver;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(VAULT_MANAGER_ROLE, _admin);
    }

    // ───────────────────────── lender actions ────────────────────────────────

    /// @notice Deposit an item and list it for rent.
    /// @param itemId         ERC1155 token ID.
    /// @param amount         Amount to list (transferred into vault).
    /// @param pricePerPeriod ETH price per rental period.
    /// @return listingId     The new listing ID.
    function listItem(
        uint256 itemId,
        uint256 amount,
        uint256 pricePerPeriod
    ) external nonReentrant returns (uint256 listingId) {
        require(amount > 0, "RentalVault: zero amount");
        require(pricePerPeriod > 0, "RentalVault: zero price");

        items.safeTransferFrom(msg.sender, address(this), itemId, amount, "");

        listingId = nextListingId++;
        _listings[listingId] = Listing({
            lender:         msg.sender,
            itemId:         itemId,
            amount:         amount,
            pricePerPeriod: pricePerPeriod,
            rented:         false,
            renter:         address(0),
            rentalEnd:      0
        });

        emit ItemListed(listingId, msg.sender, itemId, amount, pricePerPeriod);
    }

    /// @notice Cancel a listing that is not currently rented (lender only).
    function cancelListing(uint256 listingId) external nonReentrant {
        Listing storage l = _getActiveListing(listingId);
        if (l.lender != msg.sender) revert NotLender(listingId);
        if (l.rented) revert AlreadyRented(listingId);

        uint256 itemId = l.itemId;
        uint256 amount = l.amount;
        delete _listings[listingId];

        items.safeTransferFrom(address(this), msg.sender, itemId, amount, "");
        emit ListingCancelled(listingId);
    }

    // ───────────────────────── renter actions ────────────────────────────────

    /// @notice Pay for a rental and receive the item for `rentalPeriod` seconds.
    function rentItem(uint256 listingId) external payable nonReentrant {
        Listing storage l = _getActiveListing(listingId);
        if (l.rented) revert AlreadyRented(listingId);
        if (msg.value < l.pricePerPeriod) {
            revert InsufficientPayment(msg.value, l.pricePerPeriod);
        }

        // Protocol fee
        uint256 fee     = (l.pricePerPeriod * protocolFeeBps) / 10_000;
        uint256 payout  = l.pricePerPeriod - fee;
        uint256 excess  = msg.value - l.pricePerPeriod;

        l.rented    = true;
        l.renter    = msg.sender;
        l.rentalEnd = block.timestamp + rentalPeriod;

        // Transfer item to renter
        items.safeTransferFrom(address(this), msg.sender, l.itemId, l.amount, "");

        // Pay lender
        (bool ok1,) = l.lender.call{ value: payout }("");
        require(ok1, "RentalVault: lender payment failed");

        // Pay protocol fee
        if (fee > 0) {
            (bool ok2,) = feeReceiver.call{ value: fee }("");
            require(ok2, "RentalVault: fee payment failed");
        }

        // Refund excess ETH
        if (excess > 0) {
            (bool ok3,) = msg.sender.call{ value: excess }("");
            require(ok3, "RentalVault: refund failed");
        }

        emit ItemRented(listingId, msg.sender, l.rentalEnd, l.pricePerPeriod);
    }

    // ───────────────────────── reclaim ───────────────────────────────────────

    /// @notice After rental expiry, anyone can return the item to the lender.
    function reclaimItem(uint256 listingId) external nonReentrant {
        Listing storage l = _getActiveListing(listingId);
        if (!l.rented) revert NotRented(listingId);
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp < l.rentalEnd) {
            revert RentalNotExpired(listingId, l.rentalEnd);
        }

        address renter = l.renter;
        address lender = l.lender;
        uint256 itemId = l.itemId;
        uint256 amount = l.amount;

        l.rented  = false;
        l.renter  = address(0);
        l.rentalEnd = 0;

        // Pull item back from renter (renter must have approved vault)
        items.safeTransferFrom(renter, address(this), itemId, amount, "");
        // Return to lender
        items.safeTransferFrom(address(this), lender, itemId, amount, "");

        emit ItemReclaimed(listingId, lender);
    }

    // ───────────────────────── governance ────────────────────────────────────

    function setRentalPeriod(uint256 newPeriod) external onlyRole(VAULT_MANAGER_ROLE) {
        require(newPeriod > 0, "RentalVault: zero period");
        emit RentalPeriodUpdated(rentalPeriod, newPeriod);
        rentalPeriod = newPeriod;
    }

    function setProtocolFeeBps(uint256 newFee) external onlyRole(VAULT_MANAGER_ROLE) {
        if (newFee > 2_000) revert InvalidFee(); // max 20%
        emit ProtocolFeeUpdated(protocolFeeBps, newFee);
        protocolFeeBps = newFee;
    }

    function setFeeReceiver(address newReceiver) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newReceiver != address(0), "RentalVault: zero receiver");
        feeReceiver = newReceiver;
    }

    // ───────────────────────── views ─────────────────────────────────────────

    function getListing(uint256 listingId) external view returns (Listing memory) {
        return _listings[listingId];
    }

    // ───────────────────────── ERC1155 receiver ──────────────────────────────

    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        external pure override returns (bytes4)
    {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external pure override returns (bytes4)
    {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId)
        public view override(AccessControl, IERC165) returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // ───────────────────────── internal ──────────────────────────────────────

    function _getActiveListing(uint256 listingId) internal view returns (Listing storage) {
        require(listingId < nextListingId, "RentalVault: listing not found");
        return _listings[listingId];
    }

    receive() external payable {}
}

