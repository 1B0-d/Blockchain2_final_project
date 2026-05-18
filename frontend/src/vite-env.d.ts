/// <reference types="vite/client" />

interface EthereumProvider {
  request(args: { method: string; params?: unknown[] | Record<string, unknown>[] }): Promise<any>;
}

interface Window {
  ethereum?: EthereumProvider;
}

