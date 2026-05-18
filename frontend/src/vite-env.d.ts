/// <reference types="vite/client" />

interface EthereumProvider {
  request(args: { method: string; params?: unknown[] | Record<string, unknown>[] }): Promise<any>;
  on?(event: string, handler: (...args: any[]) => void): void;
  removeListener?(event: string, handler: (...args: any[]) => void): void;
}

interface Window {
  ethereum?: EthereumProvider;
}
