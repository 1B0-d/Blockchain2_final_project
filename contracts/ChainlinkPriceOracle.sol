// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

/// @title AggregatorV3Interface
/// @notice Minimal Chainlink Data Feed interface.
interface AggregatorV3Interface {
    function decimals() external view returns (uint8);
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

/// @title ChainlinkPriceOracle
/// @notice Wraps a Chainlink price feed with staleness and sanity checks.
///         Used by the GameFi protocol to price items or treasury assets.
///
///         Demonstrates mandatory requirement: Chainlink oracle integration
///         with proper staleness check.
///
///         Staleness check: revert if `updatedAt < block.timestamp - maxStaleness`.
///         Sanity check:    revert if price ≤ 0 (handles deprecated / broken feeds).
///         Round check:     revert if answeredInRound < roundId (incomplete round).
contract ChainlinkPriceOracle is AccessControl {
    // ───────────────────────── roles ─────────────────────────────────────────
    bytes32 public constant ORACLE_MANAGER_ROLE = keccak256("ORACLE_MANAGER_ROLE");

    // ───────────────────────── state ─────────────────────────────────────────
    AggregatorV3Interface public priceFeed;

    /// @notice Maximum age of a price in seconds before it is considered stale.
    uint256 public maxStaleness;

    // ───────────────────────── events ────────────────────────────────────────
    event PriceFeedUpdated(address indexed oldFeed, address indexed newFeed);
    event MaxStalenessUpdated(uint256 oldValue, uint256 newValue);

    // ───────────────────────── errors ────────────────────────────────────────
    error StalePrice(uint256 updatedAt, uint256 maxAge);
    error InvalidPrice(int256 price);
    error IncompleteRound(uint80 roundId, uint80 answeredInRound);
    error ZeroAddress();

    // ───────────────────────── constructor ───────────────────────────────────
    constructor(
        address _priceFeed,
        uint256 _maxStaleness,
        address _admin
    ) {
        if (_priceFeed == address(0) || _admin == address(0)) revert ZeroAddress();
        require(_maxStaleness > 0, "Oracle: zero staleness");

        priceFeed    = AggregatorV3Interface(_priceFeed);
        maxStaleness = _maxStaleness;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ORACLE_MANAGER_ROLE, _admin);
    }

    // ───────────────────────── price read ────────────────────────────────────

    /// @notice Returns the latest valid price, reverting on any anomaly.
    /// @return price     Latest price (in feed's native unit).
    /// @return decimals  Feed decimals (for downstream scaling).
    function getLatestPrice() external view returns (int256 price, uint8 decimals) {
        (
            uint80 roundId,
            int256 answer,
            ,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();

        // ── Staleness check ──────────────────────────────────────────────────
        // updatedAt == 0 means the round has not yet been finalized.
        // forge-lint: disable-next-line(block-timestamp)
        if (updatedAt == 0 || block.timestamp - updatedAt > maxStaleness) {
            revert StalePrice(updatedAt, maxStaleness);
        }

        // ── Sanity check ─────────────────────────────────────────────────────
        // Chainlink returns 0 or negative for deprecated / circuit-broken feeds.
        if (answer <= 0) {
            revert InvalidPrice(answer);
        }

        // ── Round completeness check ──────────────────────────────────────────
        // answeredInRound < roundId means data from an incomplete round leaked.
        if (answeredInRound < roundId) {
            revert IncompleteRound(roundId, answeredInRound);
        }

        price    = answer;
        decimals = priceFeed.decimals();
    }

    /// @notice Convenience: returns price scaled to 18 decimals.
    function getLatestPriceScaled() external view returns (uint256 scaledPrice) {
        (int256 price, uint8 dec) = this.getLatestPrice();
        // price > 0 guaranteed by getLatestPrice
        // forge-lint: disable-next-line(unsafe-typecast)
        scaledPrice = uint256(price);
        if (dec < 18) {
            scaledPrice *= 10 ** (18 - dec);
        } else if (dec > 18) {
            scaledPrice /= 10 ** (dec - 18);
        }
    }

    // ───────────────────────── governance ────────────────────────────────────

    function setPriceFeed(address newFeed) external onlyRole(ORACLE_MANAGER_ROLE) {
        if (newFeed == address(0)) revert ZeroAddress();
        emit PriceFeedUpdated(address(priceFeed), newFeed);
        priceFeed = AggregatorV3Interface(newFeed);
    }

    function setMaxStaleness(uint256 newStaleness) external onlyRole(ORACLE_MANAGER_ROLE) {
        require(newStaleness > 0, "Oracle: zero staleness");
        emit MaxStalenessUpdated(maxStaleness, newStaleness);
        maxStaleness = newStaleness;
    }
}
