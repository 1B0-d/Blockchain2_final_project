// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Governor } from "@openzeppelin/contracts/governance/Governor.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import { GovernorCountingSimple } from
    "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import { GovernorTimelockControl } from
    "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import { GovernorVotes } from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import { GovernorVotesQuorumFraction } from
    "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import { GameToken } from "./GameToken.sol";

/// @title GameGovernor
/// @notice DAO governor for GameFi protocol parameter and treasury changes.
contract GameGovernor is
    Governor,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl
{
    uint48 public constant VOTING_DELAY_BLOCKS = 7_200; // about 1 day at 12s/block
    uint32 public constant VOTING_PERIOD_BLOCKS = 50_400; // about 1 week at 12s/block
    uint256 public constant QUORUM_NUMERATOR = 4;
    uint256 public constant PROPOSAL_THRESHOLD_NUMERATOR = 1;
    uint256 public constant PROPOSAL_THRESHOLD_DENOMINATOR = 100;
    uint256 public constant TIMELOCK_DELAY = 2 days;

    error TimelockDelayMismatch(uint256 actualDelay, uint256 expectedDelay);
    error ZeroAddress();

    constructor(GameToken token_, TimelockController timelock_)
        Governor("GameFi Governor")
        GovernorVotes(token_)
        GovernorVotesQuorumFraction(QUORUM_NUMERATOR)
        GovernorTimelockControl(timelock_)
    {
        if (address(token_) == address(0) || address(timelock_) == address(0)) {
            revert ZeroAddress();
        }

        uint256 minDelay = timelock_.getMinDelay();
        if (minDelay != TIMELOCK_DELAY) {
            revert TimelockDelayMismatch(minDelay, TIMELOCK_DELAY);
        }
    }

    function votingDelay() public pure override(Governor) returns (uint256) {
        return VOTING_DELAY_BLOCKS;
    }

    function votingPeriod() public pure override(Governor) returns (uint256) {
        return VOTING_PERIOD_BLOCKS;
    }

    /// @notice Proposal threshold is 1% of the previous block's total voting supply.
    function proposalThreshold() public view override(Governor) returns (uint256) {
        uint48 currentClock = clock();
        if (currentClock == 0) {
            return 0;
        }

        return (
            token().getPastTotalSupply(currentClock - 1) * PROPOSAL_THRESHOLD_NUMERATOR
        ) / PROPOSAL_THRESHOLD_DENOMINATOR;
    }

    function state(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    function proposalNeedsQueuing(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (bool)
    {
        return super.proposalNeedsQueuing(proposalId);
    }

    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal
        view
        override(Governor, GovernorTimelockControl)
        returns (address)
    {
        return super._executor();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(Governor)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

