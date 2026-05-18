import type { JsonRpcSigner, TransactionRequest } from "ethers";

export async function getTxOverrides(signer: JsonRpcSigner): Promise<TransactionRequest> {
  const feeData = await signer.provider.getFeeData();
  const overrides: TransactionRequest = {};
  const bump = (value: bigint) => (value * 3n) / 2n + 1_000_000n;

  if (feeData.maxFeePerGas && feeData.maxPriorityFeePerGas) {
    overrides.maxFeePerGas = bump(feeData.maxFeePerGas);
    overrides.maxPriorityFeePerGas = bump(feeData.maxPriorityFeePerGas);
  } else if (feeData.gasPrice) {
    overrides.gasPrice = bump(feeData.gasPrice);
  }

  return overrides;
}
