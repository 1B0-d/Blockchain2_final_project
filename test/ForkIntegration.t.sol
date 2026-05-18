// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";

interface IERC20MetadataFork {
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function balanceOf(address account) external view returns (uint256);
}

interface IUniswapV2RouterFork {
    function WETH() external pure returns (address);
    function factory() external pure returns (address);
}

interface IChainlinkFeedFork {
    function decimals() external view returns (uint8);
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

contract ForkIntegrationTest is Test {
    address private constant MAINNET_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address private constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address private constant CHAINLINK_ETH_USD = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address private constant USDC_TREASURY = 0x55FE002aefF02F77364de339a1292923A15844B8;

    function _selectMainnetForkOrSkip() internal {
        string memory rpcUrl = vm.envOr("MAINNET_RPC_URL", string(""));
        if (bytes(rpcUrl).length == 0) {
            vm.skip(true, "MAINNET_RPC_URL not set");
        }
        vm.createSelectFork(rpcUrl);
    }

    function testFork_USDCMetadataAndBalance() public {
        _selectMainnetForkOrSkip();

        IERC20MetadataFork usdc = IERC20MetadataFork(MAINNET_USDC);
        assertEq(usdc.decimals(), 6);
        assertEq(usdc.symbol(), "USDC");
        assertGt(usdc.balanceOf(USDC_TREASURY), 0);
    }

    function testFork_UniswapV2RouterConfiguration() public {
        _selectMainnetForkOrSkip();

        IUniswapV2RouterFork router = IUniswapV2RouterFork(UNISWAP_V2_ROUTER);
        assertEq(router.WETH(), 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        assertEq(router.factory(), 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
    }

    function testFork_ChainlinkEthUsdFeedIsFreshAndPositive() public {
        _selectMainnetForkOrSkip();

        IChainlinkFeedFork feed = IChainlinkFeedFork(CHAINLINK_ETH_USD);
        (, int256 answer,, uint256 updatedAt, uint80 answeredInRound) = feed.latestRoundData();
        assertEq(feed.decimals(), 8);
        assertGt(answer, 0);
        assertGt(updatedAt, 0);
        assertGt(answeredInRound, 0);
    }
}

