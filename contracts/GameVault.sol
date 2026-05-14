// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC4626 } from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

/// @title GameVault
/// @notice ERC4626 vault for protocol fees and game economy rewards.
contract GameVault is ERC4626, Ownable {
    using SafeERC20 for IERC20;

    event RewardsDonated(address indexed donor, uint256 assets);
    event NonAssetTokenRecovered(address indexed token, address indexed to, uint256 amount);

    constructor(IERC20 asset_, address initialOwner)
        ERC20("GameFi Yield Vault", "gGAME")
        ERC4626(asset_)
        Ownable(initialOwner)
    {
        require(address(asset_) != address(0), "GameVault: zero asset");
        require(initialOwner != address(0), "GameVault: zero owner");
    }

    function donateRewards(uint256 assets) external {
        require(assets > 0, "GameVault: zero assets");

        IERC20(asset()).safeTransferFrom(msg.sender, address(this), assets);
        emit RewardsDonated(msg.sender, assets);
    }

    function recoverNonAssetToken(IERC20 token, address to, uint256 amount) external onlyOwner {
        require(address(token) != asset(), "GameVault: cannot recover asset");
        require(to != address(0), "GameVault: zero recipient");

        token.safeTransfer(to, amount);
        emit NonAssetTokenRecovered(address(token), to, amount);
    }
}

