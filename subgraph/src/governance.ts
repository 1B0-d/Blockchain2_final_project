import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import {
  ProposalCreated,
  VoteCast,
  ProposalQueued,
  ProposalExecuted,
  ProposalCanceled,
} from "../generated/GameGovernor/GameGovernor";
import { Proposal, Vote } from "../generated/schema";

export function handleProposalCreated(event: ProposalCreated): void {
  let id = event.params.proposalId.toString();
  let proposal = new Proposal(id);
  proposal.proposer = event.params.proposer;

  // Store targets as Bytes array
  let targets: Bytes[] = [];
  for (let i = 0; i < event.params.targets.length; i++) {
    targets.push(event.params.targets[i]);
  }
  proposal.targets = targets;

  proposal.description = event.params.description;
  proposal.startBlock = event.params.voteStart;
  proposal.endBlock = event.params.voteEnd;
  proposal.state = "Pending";
  proposal.forVotes = BigInt.fromI32(0);
  proposal.againstVotes = BigInt.fromI32(0);
  proposal.abstainVotes = BigInt.fromI32(0);
  proposal.save();
}

export function handleVoteCast(event: VoteCast): void {
  let proposalId = event.params.proposalId.toString();
  let proposal = Proposal.load(proposalId);
  if (proposal == null) return;

  // support: 0=Against, 1=For, 2=Abstain
  if (event.params.support == 0) {
    proposal.againstVotes = proposal.againstVotes.plus(event.params.weight);
  } else if (event.params.support == 1) {
    proposal.forVotes = proposal.forVotes.plus(event.params.weight);
  } else {
    proposal.abstainVotes = proposal.abstainVotes.plus(event.params.weight);
  }
  proposal.state = "Active";
  proposal.save();

  let voteId = proposalId + "-" + event.params.voter.toHexString();
  let vote = new Vote(voteId);
  vote.proposal = proposalId;
  vote.voter = event.params.voter;
  vote.support = event.params.support;
  vote.weight = event.params.weight;
  vote.reason = event.params.reason;
  vote.timestamp = event.block.timestamp;
  vote.blockNumber = event.block.number;
  vote.save();
}

export function handleProposalQueued(event: ProposalQueued): void {
  let id = event.params.proposalId.toString();
  let proposal = Proposal.load(id);
  if (proposal == null) return;
  proposal.state = "Queued";
  proposal.queuedAt = event.block.timestamp;
  proposal.save();
}

export function handleProposalExecuted(event: ProposalExecuted): void {
  let id = event.params.proposalId.toString();
  let proposal = Proposal.load(id);
  if (proposal == null) return;
  proposal.state = "Executed";
  proposal.executedAt = event.block.timestamp;
  proposal.save();
}

export function handleProposalCanceled(event: ProposalCanceled): void {
  let id = event.params.proposalId.toString();
  let proposal = Proposal.load(id);
  if (proposal == null) return;
  proposal.state = "Canceled";
  proposal.canceledAt = event.block.timestamp;
  proposal.save();
}
