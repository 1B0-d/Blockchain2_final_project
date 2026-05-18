import { BigInt, Address } from "@graphprotocol/graph-ts";
import {
  Swap as SwapEvent,
  LiquidityAdded,
  LiquidityRemoved,
  FeeUpdated,
} from "../generated/ResourceAMM/ResourceAMM";
import { Pool, Swap, LiquidityEvent } from "../generated/schema";

// ─── helpers ─────────────────────────────────────────────────────────────────

function loadOrCreatePool(address: Address): Pool {
  let id = address.toHexString();
  let pool = Pool.load(id);
  if (pool == null) {
    pool = new Pool(id);
    pool.tokenA = BigInt.fromI32(0);
    pool.tokenB = BigInt.fromI32(0);
    pool.reserveA = BigInt.fromI32(0);
    pool.reserveB = BigInt.fromI32(0);
    pool.feeBps = BigInt.fromI32(30);
    pool.totalShares = BigInt.fromI32(0);
    pool.totalVolumeA = BigInt.fromI32(0);
    pool.totalVolumeB = BigInt.fromI32(0);
    pool.swapCount = BigInt.fromI32(0);
  }
  return pool as Pool;
}

// ─── handlers ────────────────────────────────────────────────────────────────

export function handleSwap(event: SwapEvent): void {
  let pool = loadOrCreatePool(event.address);

  // Update volume counters
  if (event.params.tokenIn == pool.tokenA) {
    pool.totalVolumeA = pool.totalVolumeA.plus(event.params.amountIn);
  } else {
    pool.totalVolumeB = pool.totalVolumeB.plus(event.params.amountIn);
  }
  pool.swapCount = pool.swapCount.plus(BigInt.fromI32(1));
  pool.save();

  let id = event.transaction.hash.toHexString() + "-" + event.logIndex.toString();
  let swap = new Swap(id);
  swap.pool = pool.id;
  swap.trader = event.params.trader;
  swap.tokenIn = event.params.tokenIn;
  swap.amountIn = event.params.amountIn;
  swap.tokenOut = event.params.tokenOut;
  swap.amountOut = event.params.amountOut;
  swap.fee = event.params.fee;
  swap.timestamp = event.block.timestamp;
  swap.blockNumber = event.block.number;
  swap.save();
}

export function handleLiquidityAdded(event: LiquidityAdded): void {
  let pool = loadOrCreatePool(event.address);
  pool.reserveA = pool.reserveA.plus(event.params.amountA);
  pool.reserveB = pool.reserveB.plus(event.params.amountB);
  pool.totalShares = pool.totalShares.plus(event.params.shares);
  pool.save();

  let id = event.transaction.hash.toHexString() + "-" + event.logIndex.toString();
  let liqEvent = new LiquidityEvent(id);
  liqEvent.pool = pool.id;
  liqEvent.provider = event.params.provider;
  liqEvent.type = "ADD";
  liqEvent.amountA = event.params.amountA;
  liqEvent.amountB = event.params.amountB;
  liqEvent.shares = event.params.shares;
  liqEvent.timestamp = event.block.timestamp;
  liqEvent.blockNumber = event.block.number;
  liqEvent.save();
}

export function handleLiquidityRemoved(event: LiquidityRemoved): void {
  let pool = loadOrCreatePool(event.address);
  pool.reserveA = pool.reserveA.minus(event.params.amountA);
  pool.reserveB = pool.reserveB.minus(event.params.amountB);
  pool.totalShares = pool.totalShares.minus(event.params.shares);
  pool.save();

  let id = event.transaction.hash.toHexString() + "-" + event.logIndex.toString();
  let liqEvent = new LiquidityEvent(id);
  liqEvent.pool = pool.id;
  liqEvent.provider = event.params.provider;
  liqEvent.type = "REMOVE";
  liqEvent.amountA = event.params.amountA;
  liqEvent.amountB = event.params.amountB;
  liqEvent.shares = event.params.shares;
  liqEvent.timestamp = event.block.timestamp;
  liqEvent.blockNumber = event.block.number;
  liqEvent.save();
}

export function handleFeeUpdated(event: FeeUpdated): void {
  let pool = loadOrCreatePool(event.address);
  pool.feeBps = event.params.newFee;
  pool.save();
}
