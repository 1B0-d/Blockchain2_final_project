// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ResourceAMM } from "./ResourceAMM.sol";

/// @title ItemPoolFactory
/// @notice Deploys ResourceAMM pool contracts using both CREATE and CREATE2.
///
///         Demonstrates mandatory requirements:
///           • CREATE  — `deployPool`  (standard deployment, address unpredictable)
///           • CREATE2 — `deployPool2` (deterministic address, precomputable)
///
/// @dev    The factory tracks all deployed pools for off-chain indexing.
contract ItemPoolFactory is AccessControl {
    // ───────────────────────── roles ─────────────────────────────────────────
    bytes32 public constant FACTORY_MANAGER_ROLE = keccak256("FACTORY_MANAGER_ROLE");

    // ───────────────────────── state ─────────────────────────────────────────
    address[] public allPools;

    /// @dev tokenA => tokenB => pool (only stores the last deployed pair)
    mapping(uint256 => mapping(uint256 => address)) public getPool;

    // ───────────────────────── events ────────────────────────────────────────
    event PoolCreated(
        address indexed pool,
        address indexed items,
        uint256 tokenA,
        uint256 tokenB,
        bytes32 salt,          // bytes32(0) for CREATE
        bool    deterministic
    );

    // ───────────────────────── errors ────────────────────────────────────────
    error PoolAlreadyExists(uint256 tokenA, uint256 tokenB);
    error DeploymentFailed();

    // ───────────────────────── constructor ───────────────────────────────────
    constructor(address _admin) {
        require(_admin != address(0), "Factory: zero admin");
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(FACTORY_MANAGER_ROLE, _admin);
    }

    // ───────────────────────── CREATE deployment ─────────────────────────────

    /// @notice Deploy a new ResourceAMM pool with standard CREATE opcode.
    ///         Address is determined by sender + nonce (unpredictable off-chain).
    function deployPool(
        address _items,
        uint256 _tokenA,
        uint256 _tokenB,
        uint256 _feeBps,
        address _feeReceiver
    ) external onlyRole(FACTORY_MANAGER_ROLE) returns (address pool) {
        (uint256 tA, uint256 tB) = _sortTokens(_tokenA, _tokenB);

        // Revert if pair already exists (per sorted order)
        if (getPool[tA][tB] != address(0)) revert PoolAlreadyExists(tA, tB);

        // ── CREATE ──
        pool = address(new ResourceAMM(
            _items,
            tA,
            tB,
            _feeBps,
            _feeReceiver,
            address(this)          // factory is admin; transfer after if needed
        ));

        _register(pool, _items, tA, tB, bytes32(0), false);
    }

    // ───────────────────────── CREATE2 deployment ────────────────────────────

    /// @notice Deploy a new ResourceAMM pool with CREATE2 (deterministic address).
    ///         The address can be computed off-chain before deployment via `predictAddress`.
    /// @param salt  Arbitrary bytes32 chosen by caller; must be unique per deployment.
    function deployPool2(
        address _items,
        uint256 _tokenA,
        uint256 _tokenB,
        uint256 _feeBps,
        address _feeReceiver,
        bytes32 salt
    ) external onlyRole(FACTORY_MANAGER_ROLE) returns (address pool) {
        (uint256 tA, uint256 tB) = _sortTokens(_tokenA, _tokenB);

        if (getPool[tA][tB] != address(0)) revert PoolAlreadyExists(tA, tB);

        bytes memory creationCode = abi.encodePacked(
            type(ResourceAMM).creationCode,
            abi.encode(_items, tA, tB, _feeBps, _feeReceiver, address(this))
        );

        // ── CREATE2 ──
        assembly ("memory-safe") {
            pool := create2(0, add(creationCode, 0x20), mload(creationCode), salt)
        }
        if (pool == address(0)) revert DeploymentFailed();

        _register(pool, _items, tA, tB, salt, true);
    }

    // ───────────────────────── address prediction ────────────────────────────

    /// @notice Compute the deterministic address for a CREATE2 pool before deployment.
    function predictAddress(
        address _items,
        uint256 _tokenA,
        uint256 _tokenB,
        uint256 _feeBps,
        address _feeReceiver,
        bytes32 salt
    ) external view returns (address predicted) {
        (uint256 tA, uint256 tB) = _sortTokens(_tokenA, _tokenB);

        bytes32 bytecodeHash = keccak256(
            abi.encodePacked(
                type(ResourceAMM).creationCode,
                abi.encode(_items, tA, tB, _feeBps, _feeReceiver, address(this))
            )
        );

        predicted = address(uint160(uint256(
            keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, bytecodeHash))
        )));
    }

    // ───────────────────────── views ─────────────────────────────────────────

    function allPoolsLength() external view returns (uint256) {
        return allPools.length;
    }

    // ───────────────────────── internal ──────────────────────────────────────

    function _register(
        address pool,
        address _items,
        uint256 tA,
        uint256 tB,
        bytes32 salt,
        bool deterministic
    ) internal {
        allPools.push(pool);
        getPool[tA][tB] = pool;
        getPool[tB][tA] = pool; // both directions
        emit PoolCreated(pool, _items, tA, tB, salt, deterministic);
    }

    /// @notice Canonical token ordering: lower ID first.
    function _sortTokens(uint256 a, uint256 b)
        internal pure returns (uint256, uint256)
    {
        return a < b ? (a, b) : (b, a);
    }
}
