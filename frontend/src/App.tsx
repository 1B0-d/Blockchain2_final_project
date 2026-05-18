import React, { useState } from "react";
import { useWallet } from "./hooks/useWallet";
import { SwapPanel } from "./components/SwapPanel";
import { CraftPanel } from "./components/CraftPanel";
import { GovernancePanel } from "./components/GovernancePanel";
import "./App.css";

type Page = "swap" | "craft" | "governance";

export default function App() {
  const wallet = useWallet();
  const [page, setPage] = useState<Page>("swap");

  return (
    <div className="app">
      {/* ── Header ── */}
      <header className="app-header">
        <div className="logo">
          <span className="logo-icon">⚔️</span>
          <span>GameFi Protocol</span>
        </div>
        <nav>
          <button className={page === "swap"       ? "nav-btn active" : "nav-btn"} onClick={() => setPage("swap")}>Swap</button>
          <button className={page === "craft"      ? "nav-btn active" : "nav-btn"} onClick={() => setPage("craft")}>Craft & Vault</button>
          <button className={page === "governance" ? "nav-btn active" : "nav-btn"} onClick={() => setPage("governance")}>Governance</button>
        </nav>
        <div className="wallet-section">
          {wallet.address ? (
            <div className="wallet-info">
              {!wallet.isOnArbitrumSepolia && (
                <button className="btn-warn" onClick={wallet.switchToArbitrumSepolia}>
                  Switch to Arbitrum Sepolia
                </button>
              )}
              <span className="address">
                {wallet.address.slice(0, 6)}…{wallet.address.slice(-4)}
              </span>
              <span className={`chain-badge ${wallet.isOnArbitrumSepolia ? "ok" : "wrong"}`}>
                {wallet.isOnArbitrumSepolia ? "Arbitrum Sepolia" : "Wrong network"}
              </span>
            </div>
          ) : (
            <button className="btn-connect" onClick={wallet.connect} disabled={wallet.connecting}>
              {wallet.connecting ? "Connecting…" : "Connect Wallet"}
            </button>
          )}
        </div>
      </header>

      {/* ── Main ── */}
      <main className="app-main">
        {!wallet.signer || !wallet.address ? (
          <div className="connect-prompt">
            <div className="connect-card">
              <h1>GameFi Economy Protocol</h1>
              <p>Trade resources, craft items, earn yield, and govern the protocol — all on-chain.</p>
              <ul className="feature-list">
                <li>🔄 <strong>Swap</strong> — constant-product AMM for ERC1155 resources</li>
                <li>⚒️ <strong>Craft</strong> — burn ingredients, mint items</li>
                <li>🏦 <strong>Vault</strong> — deposit GAME tokens, earn yield (ERC4626)</li>
                <li>🗳️ <strong>Vote</strong> — DAO governance with timelock</li>
              </ul>
              <button className="btn-connect large" onClick={wallet.connect} disabled={wallet.connecting}>
                {wallet.connecting ? "Connecting…" : "Connect MetaMask"}
              </button>
              {wallet.error && <p className="error">{wallet.error}</p>}
            </div>
          </div>
        ) : !wallet.isOnArbitrumSepolia ? (
          <div className="connect-prompt">
            <div className="connect-card">
              <h1>Wrong Network</h1>
              <p>This deployment is on Arbitrum Sepolia.</p>
              <button className="btn-connect large" onClick={wallet.switchToArbitrumSepolia}>
                Switch to Arbitrum Sepolia
              </button>
            </div>
          </div>
        ) : (
          <div className="content">
            {page === "swap"       && <SwapPanel signer={wallet.signer} address={wallet.address} />}
            {page === "craft"      && <CraftPanel signer={wallet.signer} address={wallet.address} />}
            {page === "governance" && <GovernancePanel signer={wallet.signer} address={wallet.address} />}
          </div>
        )}
      </main>
    </div>
  );
}
