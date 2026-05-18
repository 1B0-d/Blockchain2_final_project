import { useState, useCallback, useEffect } from "react";
import { BrowserProvider, JsonRpcSigner } from "ethers";

export interface WalletState {
  provider: BrowserProvider | null;
  signer: JsonRpcSigner | null;
  address: string | null;
  chainId: number | null;
  connecting: boolean;
  error: string | null;
}

const ARBITRUM_SEPOLIA_CHAIN_ID = 421614;

export function useWallet() {
  const [state, setState] = useState<WalletState>({
    provider: null,
    signer: null,
    address: null,
    chainId: null,
    connecting: false,
    error: null,
  });

  const connect = useCallback(async () => {
    if (!window.ethereum) {
      setState((s) => ({ ...s, error: "MetaMask not installed" }));
      return;
    }
    setState((s) => ({ ...s, connecting: true, error: null }));
    try {
      const provider = new BrowserProvider(window.ethereum);
      await provider.send("eth_requestAccounts", []);
      const signer = await provider.getSigner();
      const address = await signer.getAddress();
      const network = await provider.getNetwork();
      setState({
        provider,
        signer,
        address,
        chainId: Number(network.chainId),
        connecting: false,
        error: null,
      });
    } catch (e: unknown) {
      setState((s) => ({
        ...s,
        connecting: false,
        error: e instanceof Error ? e.message : "Connection failed",
      }));
    }
  }, []);

  const switchToArbitrumSepolia = useCallback(async () => {
    if (!window.ethereum) return;
    try {
      await window.ethereum.request({
        method: "wallet_switchEthereumChain",
        params: [{ chainId: "0x" + ARBITRUM_SEPOLIA_CHAIN_ID.toString(16) }],
      });
    } catch {
      // Chain not added — add it
      await window.ethereum.request({
        method: "wallet_addEthereumChain",
        params: [
          {
            chainId: "0x" + ARBITRUM_SEPOLIA_CHAIN_ID.toString(16),
            chainName: "Arbitrum Sepolia",
            rpcUrls: ["https://sepolia-rollup.arbitrum.io/rpc"],
            nativeCurrency: { name: "ETH", symbol: "ETH", decimals: 18 },
            blockExplorerUrls: ["https://sepolia.arbiscan.io"],
          },
        ],
      });
    }
    window.location.reload();
  }, []);

  // Re-connect on page reload if already authorised
  useEffect(() => {
    if (!window.ethereum) return;
    window.ethereum.request({ method: "eth_accounts" }).then((accounts: string[]) => {
      if (accounts.length > 0) connect();
    });
  }, [connect]);

  useEffect(() => {
    if (!window.ethereum?.on) return;

    const handleChainChanged = () => window.location.reload();
    const handleAccountsChanged = () => window.location.reload();

    window.ethereum.on("chainChanged", handleChainChanged);
    window.ethereum.on("accountsChanged", handleAccountsChanged);

    return () => {
      window.ethereum?.removeListener?.("chainChanged", handleChainChanged);
      window.ethereum?.removeListener?.("accountsChanged", handleAccountsChanged);
    };
  }, []);

  return {
    ...state,
    connect,
    switchToArbitrumSepolia,
    isOnArbitrumSepolia: state.chainId === ARBITRUM_SEPOLIA_CHAIN_ID,
  };
}
