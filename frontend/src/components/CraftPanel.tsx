import React, { useState, useEffect } from "react";
import { Contract, formatUnits } from "ethers";
import { ADDRESSES, CRAFTING_ABI, GAME_VAULT_ABI, GAME_ITEMS_ABI, GAME_TOKEN_ABI, ITEM_NAMES } from "../lib/contracts";
import { getTxOverrides } from "../lib/tx";
import type { JsonRpcSigner } from "ethers";

interface Props {
  signer: JsonRpcSigner;
  address: string;
}

interface Recipe {
  id: number;
  outputId: bigint;
  outputAmount: bigint;
  active: boolean;
  ingredients: { itemId: bigint; amount: bigint }[];
}

type Tab = "craft" | "vault";

export function CraftPanel({ signer, address }: Props) {
  const [tab, setTab] = useState<Tab>("craft");

  // Crafting state
  const [recipes, setRecipes] = useState<Recipe[]>([]);
  const [selectedRecipe, setSelectedRecipe] = useState<number>(0);

  // Vault state
  const [depositAmount, setDepositAmount] = useState("");
  const [vaultShares, setVaultShares] = useState("0");
  const [vaultTotal, setVaultTotal] = useState("0");
  const [gameBalance, setGameBalance] = useState("0");

  const [loading, setLoading] = useState(false);
  const [txHash, setTxHash] = useState("");
  const [error, setError] = useState("");

  const crafting = new Contract(ADDRESSES.Crafting, CRAFTING_ABI, signer);
  const vault    = new Contract(ADDRESSES.GameVault, GAME_VAULT_ABI, signer);
  const items    = new Contract(ADDRESSES.GameItems, GAME_ITEMS_ABI, signer);
  const token    = new Contract(ADDRESSES.GameToken, GAME_TOKEN_ABI, signer);

  useEffect(() => { loadData(); }, [address]);

  async function loadData() {
    try {
      // Load recipes
      const count = await crafting.nextRecipeId();
      const loaded: Recipe[] = [];
      for (let i = 0; i < Number(count) && i < 10; i++) {
        const r = await crafting.getRecipe(i);
        if (r.active) loaded.push({ id: i, outputId: r.outputId, outputAmount: r.outputAmount, active: r.active, ingredients: r.ingredients });
      }
      setRecipes(loaded);

      // Load vault data
      const shares = await vault.balanceOf(address);
      const total  = await vault.totalAssets();
      const bal    = await token.balanceOf(address);
      setVaultShares(formatUnits(shares, 18));
      setVaultTotal(formatUnits(total, 18));
      setGameBalance(formatUnits(bal, 18));
    } catch (_) {}
  }

  async function handleCraft() {
    setError(""); setTxHash(""); setLoading(true);
    try {
      const approved = await items.isApprovedForAll(address, ADDRESSES.Crafting);
      if (!approved) {
        const tx0 = await items.setApprovalForAll(
          ADDRESSES.Crafting,
          true,
          await getTxOverrides(signer)
        );
        await tx0.wait();
      }
      const tx = await crafting.craft(selectedRecipe, await getTxOverrides(signer));
      const receipt = await tx.wait();
      setTxHash(receipt.hash);
      await loadData();
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Craft failed");
    } finally { setLoading(false); }
  }

  async function handleDeposit() {
    setError(""); setTxHash(""); setLoading(true);
    try {
      if (!depositAmount || Number(depositAmount) <= 0) throw new Error("Enter amount");
      const amount = BigInt(Math.floor(Number(depositAmount) * 1e18));

      // Approve vault
      const assetAddr = await vault.asset();
      const assetContract = new Contract(assetAddr, GAME_TOKEN_ABI, signer);
      const allowance = await assetContract.allowance(address, ADDRESSES.GameVault);
      if (allowance < amount) {
        const tx0 = await assetContract.approve(
          ADDRESSES.GameVault,
          amount,
          await getTxOverrides(signer)
        );
        await tx0.wait();
      }

      const tx = await vault.deposit(amount, address, await getTxOverrides(signer));
      const receipt = await tx.wait();
      setTxHash(receipt.hash);
      setDepositAmount("");
      await loadData();
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Deposit failed");
    } finally { setLoading(false); }
  }

  return (
    <div className="panel">
      <h2>Craft & Vault</h2>

      <div className="tabs">
        <button className={tab === "craft" ? "active" : ""} onClick={() => setTab("craft")}>Crafting</button>
        <button className={tab === "vault" ? "active" : ""} onClick={() => setTab("vault")}>Vault (ERC4626)</button>
      </div>

      {tab === "craft" && (
        <div>
          {recipes.length === 0 ? (
            <p>No active recipes found.</p>
          ) : (
            <>
              <div className="form-group">
                <label>Recipe</label>
                <select value={selectedRecipe} onChange={(e) => setSelectedRecipe(Number(e.target.value))}>
                  {recipes.map((r) => (
                    <option key={r.id} value={r.id}>
                      #{r.id} — Craft {r.outputAmount.toString()}× {ITEM_NAMES[r.outputId.toString()] ?? `Item#${r.outputId}`}
                    </option>
                  ))}
                </select>
              </div>

              {recipes[selectedRecipe] && (
                <div className="ingredients">
                  <strong>Requires:</strong>
                  {recipes[selectedRecipe].ingredients.map((ing, i) => (
                    <span key={i}> {ing.amount.toString()}× {ITEM_NAMES[ing.itemId.toString()] ?? `Item#${ing.itemId}`}</span>
                  ))}
                </div>
              )}

              <button onClick={handleCraft} disabled={loading}>
                {loading ? "Crafting…" : "Craft Item"}
              </button>
            </>
          )}
        </div>
      )}

      {tab === "vault" && (
        <div>
          <div className="vault-info">
            <div>Your shares: <strong>{Number(vaultShares).toFixed(4)} gGAME</strong></div>
            <div>Total assets: <strong>{Number(vaultTotal).toFixed(2)} GAME</strong></div>
            <div>Your GAME balance: <strong>{Number(gameBalance).toFixed(2)}</strong></div>
          </div>

          <div className="form-group">
            <label>Deposit GAME tokens</label>
            <input
              type="number"
              placeholder="0.0"
              value={depositAmount}
              onChange={(e) => setDepositAmount(e.target.value)}
            />
          </div>
          <button onClick={handleDeposit} disabled={loading}>
            {loading ? "Depositing…" : "Deposit to Vault"}
          </button>
        </div>
      )}

      {txHash && <p className="success">✓ Tx: {txHash.slice(0, 16)}…</p>}
      {error   && <p className="error">{error}</p>}
    </div>
  );
}
