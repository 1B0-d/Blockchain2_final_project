// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title GameTreasury
/// @notice Protocol treasury owned by the governance timelock.
contract GameTreasury is Ownable {
    using SafeERC20 for IERC20;

    uint256 public spendingLimit;

    event SpendingLimitUpdated(uint256 oldLimit, uint256 newLimit);
    event EtherReleased(address indexed to, uint256 amount);
    event TokenReleased(address indexed token, address indexed to, uint256 amount);

    constructor(address timelockOwner) Ownable(timelockOwner) {}

    function setSpendingLimit(uint256 newLimit) external onlyOwner {
        emit SpendingLimitUpdated(spendingLimit, newLimit);
        spendingLimit = newLimit;
    }

    function releaseEther(address payable to, uint256 amount) external onlyOwner {
        require(to != address(0), "GameTreasury: zero recipient");
        require(amount <= address(this).balance, "GameTreasury: insufficient ETH");
        require(spendingLimit == 0 || amount <= spendingLimit, "GameTreasury: over limit");

        (bool ok,) = to.call{ value: amount }("");
        require(ok, "GameTreasury: ETH release failed");
        emit EtherReleased(to, amount);
    }

    function releaseToken(IERC20 token, address to, uint256 amount) external onlyOwner {
        require(address(token) != address(0), "GameTreasury: zero token");
        require(to != address(0), "GameTreasury: zero recipient");
        require(spendingLimit == 0 || amount <= spendingLimit, "GameTreasury: over limit");

        token.safeTransfer(to, amount);
        emit TokenReleased(address(token), to, amount);
    }

    receive() external payable {}
}

