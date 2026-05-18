// ─── Contract addresses (replace after deployment) ──────────────────────────
export const ADDRESSES = {
  GameToken:   "0x6fd3d825b3d94c4ead089eb181729aebe3180015",
  GameItems:   "0x044b55374010b4b06cb39afdc88f8c7444258f87",
  GameVault:   "0x4eeb0192bbd82b877cdb0c47f613425af422afdf",
  ResourceAMM: "0x69e951e9cf90c8d116b59276b3b68ae548fa9920",
  Crafting:    "0x9d2b2608cd9cb1abfe026f5800d5f0f6f5cf427b",
  LootDrop:    "0xf7888686a5beafc6915dfafbd97ab8423e0f0bb6",
  RentalVault: "0xdb25bdbd2505c47068205fd717a2c1486f4763b3",
  GameGovernor:"0x1e557b7e6bd98be1fa303e62eaeb36cfab52f48c",
  Timelock:    "0xb785f5b8e0f819712fef41d89bb0606655bdb7ac",
  Treasury:    "0x0851ceb4c16f9a477202cb119466cc7f39e9e161",
} as const;

// ─── Minimal ABI fragments ───────────────────────────────────────────────────

export const GAME_TOKEN_ABI = [
  "function balanceOf(address) view returns (uint256)",
  "function getVotes(address) view returns (uint256)",
  "function delegate(address delegatee)",
  "function approve(address spender, uint256 amount) returns (bool)",
  "function allowance(address owner, address spender) view returns (uint256)",
  "function totalSupply() view returns (uint256)",
] as const;

export const GAME_ITEMS_ABI = [
  "function balanceOf(address account, uint256 id) view returns (uint256)",
  "function setApprovalForAll(address operator, bool approved)",
  "function isApprovedForAll(address account, address operator) view returns (bool)",
] as const;

export const GAME_VAULT_ABI = [
  "function deposit(uint256 assets, address receiver) returns (uint256 shares)",
  "function withdraw(uint256 assets, address receiver, address owner) returns (uint256 shares)",
  "function redeem(uint256 shares, address receiver, address owner) returns (uint256 assets)",
  "function balanceOf(address) view returns (uint256)",
  "function convertToAssets(uint256 shares) view returns (uint256)",
  "function totalAssets() view returns (uint256)",
  "function asset() view returns (address)",
] as const;

export const RESOURCE_AMM_ABI = [
  "function swap(uint256 tokenIn, uint256 amountIn, uint256 minAmountOut) returns (uint256)",
  "function addLiquidity(uint256 amountA, uint256 amountB, uint256 minShares) returns (uint256)",
  "function removeLiquidity(uint256 shares, uint256 minA, uint256 minB) returns (uint256, uint256)",
  "function getReserves() view returns (uint256 reserveA, uint256 reserveB)",
  "function getAmountOut(uint256 tokenIn, uint256 amountIn) view returns (uint256)",
  "function feeBps() view returns (uint256)",
  "function lpShares(address) view returns (uint256)",
  "function totalShares() view returns (uint256)",
  "function tokenA() view returns (uint256)",
  "function tokenB() view returns (uint256)",
] as const;

export const CRAFTING_ABI = [
  "function craft(uint256 recipeId)",
  "function getRecipe(uint256 recipeId) view returns (tuple(uint256 itemId, uint256 amount)[] ingredients, uint256 outputId, uint256 outputAmount, bool active)",
  "function nextRecipeId() view returns (uint256)",
] as const;

export const GOVERNOR_ABI = [
  "function propose(address[] targets, uint256[] values, bytes[] calldatas, string description) returns (uint256)",
  "function castVote(uint256 proposalId, uint8 support) returns (uint256)",
  "function castVoteWithReason(uint256 proposalId, uint8 support, string reason) returns (uint256)",
  "function queue(address[] targets, uint256[] values, bytes[] calldatas, bytes32 descriptionHash)",
  "function execute(address[] targets, uint256[] values, bytes[] calldatas, bytes32 descriptionHash)",
  "function state(uint256 proposalId) view returns (uint8)",
  "function proposalVotes(uint256 proposalId) view returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes)",
  "function votingDelay() view returns (uint256)",
  "function votingPeriod() view returns (uint256)",
  "function quorum(uint256 blockNumber) view returns (uint256)",
  "event ProposalCreated(uint256 proposalId, address proposer, address[] targets, uint256[] values, string[] signatures, bytes[] calldatas, uint256 voteStart, uint256 voteEnd, string description)",
] as const;

// Resource IDs (mirrors GameItems.sol constants)
export const ITEM_IDS = {
  WOOD:    1n,
  IRON:    2n,
  CRYSTAL: 3n,
  SWORD:   100n,
  SHIELD:  101n,
  RELIC:   200n,
} as const;

export const ITEM_NAMES: Record<string, string> = {
  "1":   "Wood",
  "2":   "Iron",
  "3":   "Crystal",
  "100": "Sword",
  "101": "Shield",
  "200": "Relic",
};

// Subgraph endpoint
export const SUBGRAPH_URL =
  "https://api.studio.thegraph.com/query/YOUR_ID/gamefi-economy/version/latest";
