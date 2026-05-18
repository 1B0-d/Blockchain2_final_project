import { BigInt } from "@graphprotocol/graph-ts";
import {
  LootDropped,
  LootRequested,
} from "../generated/LootDrop/LootDrop";
import { LootDropEvent, LootRequest } from "../generated/schema";

export function handleLootRequested(event: LootRequested): void {
  let id = event.params.requestId.toString();
  let req = new LootRequest(id);
  req.player = event.params.player;
  req.fulfilled = false;
  req.timestamp = event.block.timestamp;
  req.blockNumber = event.block.number;
  req.save();
}

export function handleLootDropped(event: LootDropped): void {
  // Mark request fulfilled if exists
  // In mock mode there is no LootRequested event, so load might return null
  let id = event.transaction.hash.toHexString() + "-" + event.logIndex.toString();
  let drop = new LootDropEvent(id);
  drop.player = event.params.player;
  drop.itemId = event.params.itemId;
  drop.randomWord = event.params.randomWord;
  drop.timestamp = event.block.timestamp;
  drop.blockNumber = event.block.number;
  drop.save();
}
