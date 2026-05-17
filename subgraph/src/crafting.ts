import { BigInt } from "@graphprotocol/graph-ts";
import {
  ItemCrafted,
  RecipeAdded,
  CraftingCostUpdated,
} from "../../generated/Crafting/Crafting";
import { Recipe, CraftEvent } from "../../generated/schema";

export function handleRecipeAdded(event: RecipeAdded): void {
  let id = event.params.recipeId.toString();
  let recipe = new Recipe(id);
  recipe.outputId = event.params.outputId;
  recipe.outputAmount = event.params.outputAmount;
  recipe.active = true;
  recipe.craftCount = BigInt.fromI32(0);
  recipe.save();
}

export function handleItemCrafted(event: ItemCrafted): void {
  let recipeId = event.params.recipeId.toString();
  let recipe = Recipe.load(recipeId);
  if (recipe == null) return;

  recipe.craftCount = recipe.craftCount.plus(BigInt.fromI32(1));
  recipe.save();

  let id = event.transaction.hash.toHexString() + "-" + event.logIndex.toString();
  let craftEvent = new CraftEvent(id);
  craftEvent.recipe = recipeId;
  craftEvent.crafter = event.params.crafter;
  craftEvent.outputAmount = event.params.outputAmount;
  craftEvent.timestamp = event.block.timestamp;
  craftEvent.blockNumber = event.block.number;
  craftEvent.save();
}

export function handleCraftingCostUpdated(event: CraftingCostUpdated): void {
  // The recipe entity stays; cost detail is on-chain — no entity field needed
  // but we can emit a log for the subgraph explorer
  let recipeId = event.params.recipeId.toString();
  let recipe = Recipe.load(recipeId);
  if (recipe != null) recipe.save(); // touch entity so indexer picks up
}
