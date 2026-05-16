// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title YulUtils
/// @notice Demonstrates inline Yul functions alongside their Solidity equivalents.
///         Used in the gas benchmark report (docs/gas_report.md).
///
///         Every Yul function has a `_sol` counterpart to compare gas costs.
///         Both versions are covered by unit tests in test/YulUtils.t.sol.
library YulUtils {
    // ─────────────────────────────────────────────────────────────────────────
    // 1. Square root (used in ResourceAMM initial liquidity)
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Babylonian square root — Yul version.
    function sqrtYul(uint256 y) internal pure returns (uint256 z) {
        assembly ("memory-safe") {
            switch gt(y, 3)
            case 1 {
                z := y
                let x := add(div(y, 2), 1)
                for {} lt(x, z) {} {
                    z := x
                    x := div(add(div(y, x), x), 2)
                }
            }
            default {
                if gt(y, 0) { z := 1 }
            }
        }
    }

    /// @notice Babylonian square root — Solidity version (equivalent).
    function sqrtSol(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 2. Packed address + uint96 encoding (common in NFT/gaming structs)
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Pack an address and a uint96 into a single bytes32 — Yul version.
    ///         Layout: [address (160 bits) | uint96 (96 bits)]
    function packAddressAmountYul(address addr, uint96 amount)
        internal pure returns (bytes32 packed)
    {
        assembly ("memory-safe") {
            // addr occupies upper 20 bytes; amount occupies lower 12 bytes
            packed := or(shl(96, addr), amount)
        }
    }

    /// @notice Pack an address and a uint96 — Solidity version.
    function packAddressAmountSol(address addr, uint96 amount)
        internal pure returns (bytes32 packed)
    {
        packed = bytes32((uint256(uint160(addr)) << 96) | uint256(amount));
    }

    /// @notice Unpack — Yul version.
    function unpackAddressAmountYul(bytes32 packed)
        internal pure returns (address addr, uint96 amount)
    {
        assembly ("memory-safe") {
            addr   := shr(96, packed)
            amount := and(packed, 0xffffffffffffffffffffffff) // low 96 bits
        }
    }

    /// @notice Unpack — Solidity version.
    function unpackAddressAmountSol(bytes32 packed)
        internal pure returns (address addr, uint96 amount)
    {
        addr   = address(uint160(uint256(packed) >> 96));
        amount = uint96(uint256(packed));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 3. Min/max without branching
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Branchless min — Yul.
    function minYul(uint256 a, uint256 b) internal pure returns (uint256 result) {
        assembly ("memory-safe") {
            result := xor(a, mul(xor(a, b), lt(b, a)))
        }
    }

    /// @notice Branchless min — Solidity (post-0.8.13 optimizer does the same).
    function minSol(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 4. Constant-product AMM output amount (critical hot path)
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice amountOut = reserveOut - (reserveIn * reserveOut) / (reserveIn + amountIn)
    ///         Yul version: avoids Solidity checked arithmetic overhead in hot path.
    function getAmountOutYul(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        assembly ("memory-safe") {
            // No overflow check: caller must ensure reserveIn + amountIn <= type(uint256).max
            let numerator   := mul(reserveIn, reserveOut)
            let denominator := add(reserveIn, amountIn)
            amountOut := sub(reserveOut, div(numerator, denominator))
        }
    }

    /// @notice Same formula — Solidity version (with checked arithmetic).
    function getAmountOutSol(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        uint256 numerator   = reserveIn * reserveOut;
        uint256 denominator = reserveIn + amountIn;
        amountOut = reserveOut - (numerator / denominator);
    }
}
