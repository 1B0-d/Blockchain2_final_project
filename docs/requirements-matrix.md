# Requirements Coverage Matrix

Project: GameFi Economy Protocol
Option: B, GameFi economy protocol
Status date: May 2026

## Mandatory Requirements

| Requirement | Status | File / Evidence | Notes |
|-------------|--------|-----------------|-------|
| ERC20Votes | Done | `contracts/GameToken.sol` | Governance voting power and checkpoints |
| ERC20Permit | Done | `contracts/GameToken.sol` | EIP-2612 permit inherited from OpenZeppelin |
| ERC1155 | Done | `contracts/GameItems.sol` | Resources and items |
| ERC4626 | Done | `contracts/GameVault.sol` | Implemented, but dedicated coverage is still low |
| UUPS upgrade | Done | `contracts/Crafting.sol`, `contracts/CraftingV2.sol`, `test/CraftingUpgrade.t.sol` | V1 -> V2 upgrade path tested |
| CREATE/CREATE2 | Done | `contracts/ItemPoolFactory.sol`, `test/AdvancedContracts.t.sol` | Deterministic AMM pool deployment tested |
| Yul / assembly | Done | `contracts/YulUtils.sol`, `test/AdvancedContracts.t.sol` | Solidity equivalence fuzz tests present |
| AMM / DeFi primitive | Done | `contracts/ResourceAMM.sol`, `test/ResourceAMM.t.sol` | Swap, liquidity, fees, fuzz, invariants |
| Chainlink price feed | Done | `contracts/ChainlinkPriceOracle.sol`, `test/AdvancedContracts.t.sol`, `test/ForkIntegration.t.sol` | Unit-tested; fork test requires `MAINNET_RPC_URL` |
| Chainlink VRF flow | Partial | `contracts/LootDrop.sol` | VRF-compatible interface plus mock mode for local tests; real subscription deployment still needed |
| DAO governance | Done | `contracts/GameGovernor.sol`, `contracts/GameTreasury.sol`, `test/Governance.t.sol` | Proposal, voting, queue, execute lifecycle tested |
| Timelock | Done | `contracts/GameTreasury.sol`, `script/PostDeployCheck.s.sol` | 2-day delay and governor roles checked |
| The Graph subgraph | Done/Partial | `subgraph/` | Schema, mappings, YAML, ABIs, codegen, and build pass; addresses must be replaced after deployment |
| Frontend dApp | Partial | `frontend/` | Builds successfully; production contract addresses still need wiring |
| L2 deployment | Partial | `script/Deploy.s.sol` | Script exists; actual deployment/verification not recorded in repo |
| CI | Done | `.github/workflows/ci.yml` | Build, tests, coverage, Slither high gate, frontend build |

## Contract Coverage

| Contract | Status | Tests / Evidence | Notes |
|----------|--------|------------------|-------|
| `GameToken.sol` | Done | `test/Governance.t.sol` | Transfers, voting power, delegation through governance tests |
| `GameItems.sol` | Done | `test/Crafting.t.sol`, `test/AdvancedContracts.t.sol` | Mint, burn, role usage indirectly tested |
| `GameVault.sol` | Needs tests | Coverage report | Contract compiles, but coverage is currently 0% |
| `ResourceAMM.sol` | Done | `test/ResourceAMM.t.sol` | Unit, fuzz, invariant tests passing |
| `Crafting.sol` | Done | `test/Crafting.t.sol`, `test/CraftingUpgrade.t.sol` | Recipe and UUPS upgrade tests |
| `CraftingV2.sol` | Done | `test/CraftingUpgrade.t.sol` | XP feature and storage preservation tested |
| `LootDrop.sol` | Done/Partial | `test/AdvancedContracts.t.sol` | Mock loot flow tested; real VRF requires network config |
| `RentalVault.sol` | Needs tests | Coverage report | Contract compiles, but coverage is currently 0% |
| `ItemPoolFactory.sol` | Done | `test/AdvancedContracts.t.sol` | CREATE and CREATE2 tested |
| `GameGovernor.sol` | Done | `test/Governance.t.sol` | Governance lifecycle tested |
| `GameTreasury.sol` | Done | `test/Governance.t.sol` | Timelock-controlled ETH release tested |
| `ChainlinkPriceOracle.sol` | Done | `test/AdvancedContracts.t.sol`, `test/ForkIntegration.t.sol` | Unit tests pass; fork tests skip without RPC |
| `YulUtils.sol` | Done | `test/AdvancedContracts.t.sol` | Known values and fuzz equivalence |

## Verification Snapshot

| Command | Result |
|---------|--------|
| `forge build` | Pass |
| `forge test` | Pass: `87 passed, 0 failed, 3 skipped` |
| `forge coverage --report summary` | Pass: total line coverage `64.74%`, statement coverage `65.10%` |
| `npm --prefix frontend run build` | Pass |
| `npm --prefix subgraph run build` | Pass |
| `slither . --exclude-dependencies --exclude arbitrary-send-eth,weak-prng --fail-high` | Pass |

## Remaining Work Before Final Submission

| Task | Priority | Owner Suggestion |
|------|----------|------------------|
| Add dedicated `GameVault` tests | Medium | Strong Solidity teammate |
| Add dedicated `RentalVault` tests | Medium | Strong Solidity teammate |
| Deploy to Base Sepolia or Arbitrum Sepolia | High if deployment proof is required | Repo owner |
| Replace subgraph zero addresses after deployment | High after deployment | Repo owner |
| Add real VRF subscription/network config | Medium | Repo owner or strong Solidity teammate |
| Add deployed contract addresses to frontend config | High after deployment | Frontend/integration owner |
