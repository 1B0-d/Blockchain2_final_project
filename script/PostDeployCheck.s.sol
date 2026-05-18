// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console2 } from "forge-std/Script.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import { GameGovernor } from "../contracts/GameGovernor.sol";
import { GameTreasury } from "../contracts/GameTreasury.sol";

/// @notice Post-deployment verification helper.
/// @dev Reads deployed addresses from env and reverts if governance wiring is wrong.
contract PostDeployCheck is Script {
    function run() external view {
        address timelockAddress = vm.envAddress("TIMELOCK_ADDRESS");
        address governorAddress = vm.envAddress("GOVERNOR_ADDRESS");
        address treasuryAddress = vm.envAddress("TREASURY_ADDRESS");

        TimelockController timelock = TimelockController(payable(timelockAddress));
        GameGovernor governor = GameGovernor(payable(governorAddress));
        GameTreasury treasury = GameTreasury(payable(treasuryAddress));

        require(timelock.getMinDelay() == 2 days, "bad timelock delay");
        require(governor.timelock() == timelockAddress, "governor timelock mismatch");
        require(treasury.owner() == timelockAddress, "treasury owner is not timelock");
        require(governor.votingDelay() == 7_200, "bad voting delay");
        require(governor.votingPeriod() == 50_400, "bad voting period");
        require(governor.quorumNumerator() == 4, "bad quorum");
        require(timelock.hasRole(timelock.PROPOSER_ROLE(), governorAddress), "governor missing proposer");
        require(timelock.hasRole(timelock.CANCELLER_ROLE(), governorAddress), "governor missing canceller");

        console2.log("Post-deployment governance checks passed");
    }
}

