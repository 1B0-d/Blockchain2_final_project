import React, { useState, useEffect } from "react";
import { Contract, parseUnits, formatUnits } from "ethers";
import { ADDRESSES, RESOURCE_AMM_ABI, GAME_ITEMS_ABI, ITEM_IDS, ITEM_NAMES } from "../lib/contracts";
import type { JsonRpcSigner } from "ethers";

interface Props {
  signer: JsonRpcSigner;
  address: string;
}

export function SwapPanel({ signer, address }: Props) {
  const [tokenIn, setTokenIn] = useState<bigint>(ITEM_IDS.WOOD);
  const [amountIn, setAmountIn] = useState("");
  const [quote, setQuote] = useState<string>("");
  const [reserves, setReserves] = useState<{ a: string; b: string } | null>(null);
  const [balances, setBalances] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(false);
  const [txHash, setTxHash] = useState("");
  const [error, setError] = useState("");

  const amm = new Contract(ADDRESSES.ResourceAMM, RESOURCE_AMM_ABI, signer);
  const items = new Contract(ADDRESSES.GameItems, GAME_ITEMS_ABI, signer);

  const tokenOut = tokenIn === ITEM_IDS.WOOD ? ITEM_IDS.IRON : ITEM_IDS.WOOD;

  useEffect(() => {
    loadData();
  }, [address]);

  async function loadData() {
    try {
      const [rA, rB] = await amm.getReserves();
      setReserves({ a: formatUnits(rA, 0), b: formatUnits(rB, 0) });

      const woodBal = await items.balanceOf(address, ITEM_IDS.WOOD);
      const ironBal = await items.balanceOf(address, ITEM_IDS.IRON);
      setBalances({ "1": woodBal.toString(), "2": ironBal.toString() });
    } catch (_) {}
  }

  async function getQuote() {
    if (!amountIn || Number(amountIn) <= 0) return;
    try {
      const out = await amm.getAmountOut(tokenIn, BigInt(amountIn));
      setQuote(out.toString());
    } catch (_) {
      setQuote("—");
    }
  }

  async function handleSwap() {
    setError("");
    setTxHash("");
    if (!amountIn || Number(amountIn) <= 0) return setError("Enter an amount");

    setLoading(true);
    try {
      // Approve items contract first
      const approved = await items.isApprovedForAll(address, ADDRESSES.ResourceAMM);
      if (!approved) {
        const tx0 = await items.setApprovalForAll(ADDRESSES.ResourceAMM, true);
        await tx0.wait();
      }

      const minOut = quote ? (BigInt(quote) * 95n) / 100n : 0n; // 5 % slippage
      const tx = await amm.swap(tokenIn, BigInt(amountIn), minOut);
      const receipt = await tx.wait();
      setTxHash(receipt.hash);
      setAmountIn("");
      setQuote("");
      await loadData();
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Transaction failed");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="panel">
      <h2>Swap Resources</h2>

      {reserves && (
        <div className="reserves">
          <span>Pool: {reserves.a} WOOD / {reserves.b} IRON</span>
        </div>
      )}

      <div className="balances">
        <span>Wood: {balances["1"] ?? "—"}</span>
        <span>Iron: {balances["2"] ?? "—"}</span>
      </div>

      <div className="form-group">
        <label>Sell</label>
        <select value={tokenIn.toString()} onChange={(e) => setTokenIn(BigInt(e.target.value))}>
          <option value={ITEM_IDS.WOOD.toString()}>Wood (ID 1)</option>
          <option value={ITEM_IDS.IRON.toString()}>Iron (ID 2)</option>
        </select>
      </div>

      <div className="form-group">
        <label>Amount</label>
        <input
          type="number"
          placeholder="0"
          value={amountIn}
          onChange={(e) => { setAmountIn(e.target.value); setQuote(""); }}
          onBlur={getQuote}
        />
      </div>

      {quote && (
        <div className="quote">
          ≈ {quote} {ITEM_NAMES[tokenOut.toString()]} out
        </div>
      )}

      <button onClick={handleSwap} disabled={loading}>
        {loading ? "Swapping…" : `Swap → ${ITEM_NAMES[tokenOut.toString()]}`}
      </button>

      {txHash && <p className="success">✓ Tx: {txHash.slice(0, 16)}…</p>}
      {error   && <p className="error">{error}</p>}
    </div>
  );
}
