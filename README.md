# GameFi Economy Protocol
link on the video: https://youtu.be/5BYizopzF2g
Final project for Blockchain Technologies 2, Option B: a GameFi economy protocol rather
than a full game.

The protocol models an on-chain game economy where players can hold ERC1155 resources and
items, craft items, trade resources through an AMM, rent rare items, open loot boxes, and
govern economy parameters through a DAO.

## Current Status

| Area | Status | Notes |
|------|--------|-------|
| Smart contracts | Implemented | Core economy, governance, AMM, crafting, loot, rental, vault |
| Unit/fuzz/invariant tests | Passing | `87 passed, 0 failed, 3 skipped` locally |
| Fork tests | Present | Skipped unless `MAINNET_RPC_URL` is set |
| Frontend | Builds | React/Vite dApp shell |
| Subgraph | Builds | ABIs, mappings, codegen, and build pass; deployed addresses still need to be inserted |
| CI | Added | Contracts, tests, coverage, Slither high-severity gate, frontend build |
| Deployment | Scripted | `script/Deploy.s.sol` and post-deploy governance checks |

## Contracts

| Contract | Purpose |
|----------|---------|
| `GameToken.sol` | ERC20Votes + ERC20Permit governance token |
| `GameItems.sol` | ERC1155 resources and crafted items |
| `GameVault.sol` | ERC4626 vault for protocol assets/rewards |
| `ResourceAMM.sol` | Constant-product ERC1155 resource AMM |
| `Crafting.sol` / `CraftingV2.sol` | UUPS-upgradeable crafting system |
| `LootDrop.sol` | Loot box flow with Chainlink VRF-compatible interface and local mock mode |
| `RentalVault.sol` | ERC1155 item rental escrow |
| `ItemPoolFactory.sol` | CREATE/CREATE2 AMM pool factory |
| `GameGovernor.sol` | OpenZeppelin Governor |
| `GameTreasury.sol` | Timelock-owned treasury |
| `ChainlinkPriceOracle.sol` | Chainlink price feed wrapper with staleness checks |
| `YulUtils.sol` | Yul utility functions used for advanced Solidity requirement |

## Governance Parameters

| Parameter | Value |
|-----------|-------|
| Voting delay | `7_200` blocks, about 1 day at 12s/block |
| Voting period | `50_400` blocks, about 1 week at 12s/block |
| Quorum | `4%` |
| Proposal threshold | `1%` of total supply |
| Timelock delay | `2 days` |

## Project Layout

```text
contracts/      Foundry smart contracts
test/           unit, fuzz, invariant, and optional fork tests
script/         deploy and post-deployment scripts
frontend/       React dApp
subgraph/       The Graph schema, mappings, and generated ABIs
docs/           proposal, architecture, requirements, audit notes, presentation outline
.github/        CI workflow
```

## Setup

```bash
npm install
cd frontend && npm install && cd ..
forge build
forge test
```

Optional fork tests:

```bash
MAINNET_RPC_URL=<rpc-url> forge test --match-contract ForkIntegrationTest
```

Frontend build:

```bash
npm --prefix frontend run build
```

Coverage:

```bash
forge coverage --report summary
```

Slither high-severity gate:

```bash
slither . --exclude-dependencies --exclude arbitrary-send-eth,weak-prng --fail-high
```

The two excluded Slither detectors are documented design acknowledgements: rental payouts
send ETH to listed lenders/fee receivers, and `LootDrop` has a mock randomness path for
local tests while preserving the VRF-compatible production flow.

## Latest Local Verification

| Command | Result |
|---------|--------|
| `forge build` | Pass |
| `forge test` | Pass, `87 passed, 0 failed, 3 skipped` |
| `forge coverage --report summary` | Pass, total line coverage `64.74%` |
| `npm --prefix frontend run build` | Pass |
| `npm --prefix subgraph run build` | Pass |
| `slither . --exclude-dependencies --exclude arbitrary-send-eth,weak-prng --fail-high` | Pass |

Known coverage gaps: `GameVault.sol` and `RentalVault.sol` need dedicated tests if the team
wants stronger coverage numbers before submission.
