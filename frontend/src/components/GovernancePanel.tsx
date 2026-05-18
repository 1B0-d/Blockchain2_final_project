import React, { useState, useEffect } from "react";
import { Contract, formatUnits, id as ethersId } from "ethers";
import { ADDRESSES, GOVERNOR_ABI, GAME_TOKEN_ABI } from "../lib/contracts";
import { getTxOverrides } from "../lib/tx";
import type { JsonRpcSigner } from "ethers";

interface Props {
  signer: JsonRpcSigner;
  address: string;
}

const PROPOSAL_STATES = [
  "Pending", "Active", "Canceled", "Defeated",
  "Succeeded", "Queued", "Expired", "Executed",
];

const STATE_COLORS: Record<string, string> = {
  Active: "#22c55e",
  Succeeded: "#3b82f6",
  Queued: "#f59e0b",
  Executed: "#8b5cf6",
  Defeated: "#ef4444",
  Canceled: "#6b7280",
  Pending: "#94a3b8",
  Expired: "#6b7280",
};

interface ProposalInfo {
  id: string;
  description: string;
  state: string;
  forVotes: string;
  againstVotes: string;
  abstainVotes: string;
}

export function GovernancePanel({ signer, address }: Props) {
  const [votes, setVotes] = useState("0");
  const [delegateTo, setDelegateTo] = useState("");
  const [proposals, setProposals] = useState<ProposalInfo[]>([]);
  const [selectedProposal, setSelectedProposal] = useState<string>("");
  const [support, setSupport] = useState<number>(1); // 1 = For
  const [reason, setReason] = useState("");
  const [loading, setLoading] = useState(false);
  const [txHash, setTxHash] = useState("");
  const [error, setError] = useState("");

  const governor = new Contract(ADDRESSES.GameGovernor, GOVERNOR_ABI, signer);
  const token    = new Contract(ADDRESSES.GameToken, GAME_TOKEN_ABI, signer);

  useEffect(() => { loadData(); }, [address]);

  async function loadData() {
    try {
      const v = await token.getVotes(address);
      setVotes(formatUnits(v, 18));

      // Load recent proposals via events
      const filter = governor.filters.ProposalCreated();
      const events = await governor.queryFilter(filter, -10000);
      const loaded: ProposalInfo[] = await Promise.all(
        events.slice(-5).map(async (ev: any) => {
          const proposalId = ev.args.proposalId.toString();
          const stateNum = await governor.state(proposalId).catch(() => 0);
          const voteData = await governor.proposalVotes(proposalId).catch(() => [0n, 0n, 0n]);
          return {
            id: proposalId,
            description: ev.args.description.slice(0, 80),
            state: PROPOSAL_STATES[Number(stateNum)] ?? "Unknown",
            forVotes: formatUnits(voteData[1], 18),
            againstVotes: formatUnits(voteData[0], 18),
            abstainVotes: formatUnits(voteData[2], 18),
          };
        })
      );
      setProposals(loaded);
    } catch (_) {}
  }

  async function handleDelegate() {
    setError(""); setTxHash(""); setLoading(true);
    try {
      const to = delegateTo || address;
      const tx = await token.delegate(to, await getTxOverrides(signer));
      const receipt = await tx.wait();
      setTxHash(receipt.hash);
      await loadData();
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Delegation failed");
    } finally { setLoading(false); }
  }

  async function handleVote() {
    setError(""); setTxHash(""); setLoading(true);
    if (!selectedProposal) { setError("Select a proposal"); setLoading(false); return; }
    try {
      const tx = reason
        ? await governor.castVoteWithReason(
            selectedProposal,
            support,
            reason,
            await getTxOverrides(signer)
          )
        : await governor.castVote(selectedProposal, support, await getTxOverrides(signer));
      const receipt = await tx.wait();
      setTxHash(receipt.hash);
      await loadData();
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Vote failed");
    } finally { setLoading(false); }
  }

  return (
    <div className="panel">
      <h2>Governance</h2>

      {/* Voting power */}
      <div className="vault-info">
        <div>Voting power: <strong>{Number(votes).toFixed(2)} GAME</strong></div>
      </div>

      {/* Delegate */}
      <div className="form-group">
        <label>Delegate votes to (leave blank = self)</label>
        <input
          placeholder={address}
          value={delegateTo}
          onChange={(e) => setDelegateTo(e.target.value)}
        />
      </div>
      <button onClick={handleDelegate} disabled={loading} style={{ marginBottom: "1rem" }}>
        {loading ? "Delegating…" : "Delegate"}
      </button>

      {/* Proposals */}
      <h3>Active Proposals</h3>
      {proposals.length === 0 ? (
        <p style={{ color: "#94a3b8" }}>No proposals found in recent blocks.</p>
      ) : (
        <div className="proposals">
          {proposals.map((p) => (
            <div
              key={p.id}
              className={`proposal-card ${selectedProposal === p.id ? "selected" : ""}`}
              onClick={() => setSelectedProposal(p.id)}
            >
              <div className="proposal-header">
                <span className="proposal-id">#{p.id.slice(0, 8)}…</span>
                <span
                  className="proposal-state"
                  style={{ background: STATE_COLORS[p.state] ?? "#6b7280" }}
                >
                  {p.state}
                </span>
              </div>
              <p className="proposal-desc">{p.description}</p>
              <div className="vote-counts">
                <span style={{ color: "#22c55e" }}>✓ {Number(p.forVotes).toFixed(0)}</span>
                <span style={{ color: "#ef4444" }}>✗ {Number(p.againstVotes).toFixed(0)}</span>
                <span style={{ color: "#94a3b8" }}>— {Number(p.abstainVotes).toFixed(0)}</span>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Vote form */}
      {selectedProposal && (
        <div className="vote-form">
          <h3>Cast Vote</h3>
          <div className="form-group">
            <label>Support</label>
            <select value={support} onChange={(e) => setSupport(Number(e.target.value))}>
              <option value={1}>For</option>
              <option value={0}>Against</option>
              <option value={2}>Abstain</option>
            </select>
          </div>
          <div className="form-group">
            <label>Reason (optional)</label>
            <input
              placeholder="Why are you voting this way?"
              value={reason}
              onChange={(e) => setReason(e.target.value)}
            />
          </div>
          <button onClick={handleVote} disabled={loading}>
            {loading ? "Voting…" : "Cast Vote"}
          </button>
        </div>
      )}

      {txHash && <p className="success">✓ Tx: {txHash.slice(0, 16)}…</p>}
      {error   && <p className="error">{error}</p>}
    </div>
  );
}
