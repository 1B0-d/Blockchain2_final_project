// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { IGovernor } from "@openzeppelin/contracts/governance/IGovernor.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import { GameGovernor } from "../contracts/GameGovernor.sol";
import { GameToken } from "../contracts/GameToken.sol";
import { GameTreasury } from "../contracts/GameTreasury.sol";

contract GovernanceTest is Test {
    uint256 private constant TIMELOCK_DELAY = 2 days;
    uint8 private constant VOTE_FOR = 1;

    GameToken token;
    TimelockController timelock;
    GameGovernor governor;
    GameTreasury treasury;

    address voter = makeAddr("voter");

    function setUp() public {
        token = new GameToken(voter);

        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0);

        timelock = new TimelockController(TIMELOCK_DELAY, proposers, executors, address(this));
        governor = new GameGovernor(token, timelock);
        treasury = new GameTreasury(address(timelock));

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), address(this));

        vm.prank(voter);
        token.delegate(voter);
        vm.roll(block.number + 1);
    }

    function test_governorParameters_matchProjectSpec() public view {
        assertEq(governor.votingDelay(), 7_200);
        assertEq(governor.votingPeriod(), 50_400);
        assertEq(governor.quorumNumerator(), 4);
        assertEq(governor.proposalThreshold(), token.totalSupply() / 100);
        assertEq(timelock.getMinDelay(), TIMELOCK_DELAY);
        assertEq(treasury.owner(), address(timelock));
    }

    function test_fullLifecycle_updatesTreasuryThroughTimelock() public {
        uint256 newLimit = 42 ether;
        string memory description = "Set treasury spending limit";

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(treasury);
        values[0] = 0;
        calldatas[0] = abi.encodeCall(GameTreasury.setSpendingLimit, (newLimit));

        vm.prank(voter);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Pending));

        vm.roll(block.number + governor.votingDelay() + 1);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Active));

        vm.prank(voter);
        governor.castVote(proposalId, VOTE_FOR);

        vm.roll(block.number + governor.votingPeriod() + 1);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));

        bytes32 descriptionHash = keccak256(bytes(description));
        governor.queue(targets, values, calldatas, descriptionHash);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Queued));

        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);
        governor.execute(targets, values, calldatas, descriptionHash);

        assertEq(treasury.spendingLimit(), newLimit);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Executed));
    }
}
