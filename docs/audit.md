# Security Review Notes

Project: GameFi Economy Protocol
Status date: May 2026
Scope: contracts in `contracts/`, Foundry tests in `test/`, deployment scripts in `script/`

This is an internal project security review, not an external professional audit.

## Verification Summary

| Check | Result |
|-------|--------|
| `forge build` | Pass |
| `forge test` | Pass: `87 passed, 0 failed, 3 skipped` |
| `forge coverage --report summary` | Pass |
| `npm --prefix frontend run build` | Pass |
| `npm --prefix subgraph run build` | Pass |
| `slither . --exclude-dependencies --exclude arbitrary-send-eth,weak-prng --fail-high` | Pass |

Fork tests are present but skip locally unless `MAINNET_RPC_URL` is configured.

## Coverage Snapshot

Latest local `forge coverage --report summary`:

| Metric | Total |
|--------|-------|
| Lines | `64.74%` |
| Statements | `65.10%` |
| Branches | `33.02%` |
| Functions | `62.86%` |

Notable gaps:

| File | Line Coverage | Notes |
|------|---------------|-------|
| `contracts/GameVault.sol` | `0.00%` | Needs dedicated ERC4626 deposit/withdraw/reward/recovery tests |
| `contracts/RentalVault.sol` | `0.00%` | Needs listing/rent/reclaim/cancel/fee tests |
| `script/Deploy.s.sol` | `0.00%` | Script coverage is not required, but deployment should be tested on testnet |
| `script/PostDeployCheck.s.sol` | `0.00%` | Run after deployment with env addresses |

## Slither Findings

CI uses Slither as a high-severity gate with two acknowledged exclusions:

```bash
slither . --exclude-dependencies --exclude arbitrary-send-eth,weak-prng --fail-high
```

| Detector | Status | Rationale |
|----------|--------|-----------|
| `arbitrary-send-eth` | Acknowledged | `RentalVault` intentionally pays rental proceeds to the listed lender and protocol fee receiver. These flows are part of the escrow design. |
| `weak-prng` | Acknowledged | `LootDrop` includes mock-mode randomness for local tests. Production deployments should use the VRF path with a real coordinator/subscription. |
| `reentrancy-no-eth` on `ResourceAMM.swap` | Mitigated | `ResourceAMM` uses OpenZeppelin `ReentrancyGuard` and marks swap/liquidity functions `nonReentrant`. Slither still reports ERC1155 external-call patterns. |
| `calls-loop` in crafting | Acknowledged | Crafting burns each ingredient in a bounded recipe loop. Recipe complexity should be kept small by governance. |
| `timestamp` | Acknowledged | Used for oracle staleness and rental expiry, where timestamp dependence is expected. |
| `assembly` | Acknowledged | Required by the project for Yul/assembly coverage and tested against Solidity equivalents. |

## Contract Review

### `GameToken.sol`

Uses OpenZeppelin ERC20Votes and ERC20Permit. Governance tests cover delegation and voting power usage through proposals.

Residual risk: token distribution is centralized at deployment until transferred/delegated.

### `GameItems.sol`

ERC1155 item/resource contract with role-based minting and system burns.

Residual risk: admin/minter role management must be transferred to the intended governance/timelock setup after deployment.

### `GameVault.sol`

ERC4626 vault compiles, but current test coverage is missing.

Required before strong submission: deposit, withdraw, donate rewards, recover non-asset token, and unauthorized recovery tests.

### `ResourceAMM.sol`

Constant-product AMM has unit, fuzz, and invariant tests. Checks include swaps, liquidity, fees, reserve accounting, share accounting, and bounded fees.

Residual risk: ERC1155 transfers create external-call surfaces; `nonReentrant` is already applied.

### `Crafting.sol` / `CraftingV2.sol`

UUPS upgrade path is covered by tests. Recipe management and crafting are tested.

Residual risk: long recipes can increase gas and loop risk; recipe length should be controlled by governance.

### `LootDrop.sol`

Mock mode is tested locally. Real VRF mode is interface-compatible but requires network-specific coordinator, key hash, subscription, funding, and callback configuration.

Residual risk: do not present mock randomness as production randomness.

### `RentalVault.sol`

Rental escrow contract compiles but lacks dedicated tests in the current suite.

Required before strong submission: item listing, rental payment split, reclaim after expiry, early reclaim revert, cancellation, and fee config tests.

### `GameGovernor.sol` / `GameTreasury.sol`

Governance lifecycle tests pass for propose, vote, queue, execute, crafting changes, loot table changes, AMM fee changes, and treasury release.

Residual risk: final deployment must verify timelock role ownership and treasury ownership with `script/PostDeployCheck.s.sol`.

### `ChainlinkPriceOracle.sol`

Unit tests cover valid price, stale data, zero/negative price, incomplete round, scaling, and authorization. Fork test checks real ETH/USD feed freshness when RPC is provided.

Residual risk: single-feed dependency. A future version can add fallback feeds.

## Recommended Next Fixes

1. Add `GameVault` tests.
2. Add `RentalVault` tests.
3. Run fork tests with a real `MAINNET_RPC_URL`.
4. Deploy to the selected L2 testnet and record contract addresses.
5. Replace zero addresses in `subgraph/subgraph.yaml`.
6. Configure real Chainlink VRF values before claiming production randomness.
