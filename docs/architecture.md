# GameFi Economy Protocol - Architecture Document

## Project Overview

The GameFi Economy Protocol is a decentralized on-chain economy layer designed for blockchain games. It provides foundational systems for resource management, item crafting, trading, rentals, and player governance through a Decentralized Autonomous Organization (DAO).

**Project Type:** Blockchain Gaming Infrastructure  
**Blockchain:** Ethereum (L2 deployment on Base Sepolia / Arbitrum Sepolia)  
**Solidity Version:** 0.8.24  
**Framework:** Foundry + Hardhat (testing & deployment)  

---

## System Architecture

### 1. Core Token Layer

#### GameToken (ERC20Votes + ERC20Permit)
- **Purpose:** Governance and incentive token for the protocol
- **Features:**
  - `ERC20Votes`: Vote delegation and checkpoint system for on-chain governance
  - `ERC20Permit`: EIP-2612 gasless approvals via signature
  - Standard transfer, mint, and burn functionality
- **Deployment:** Mainnet with initial supply determined by DAO
- **Key Functions:**
  - `delegate(address delegatee)`: Self-delegate voting power
  - `permit(...)`: Execute approve via signature

#### GameItems (ERC1155)
- **Purpose:** Non-fungible and semi-fungible resources and items
- **Structure:**
  - **Resources:** Fungible tokens (wood, ore, crystal, etc.) - IDs 1-100
  - **Items:** Semi-fungible equipment and rare artifacts - IDs 101+
- **Key Functions:**
  - `mintBatch()`: Batch mint multiple item types
  - `burnBatch()`: Batch burn for crafting
  - `safeTransferFrom()`: Standard ERC1155 transfers with hooks
- **Burn Mechanism:** Crafting system burns resources and mints items

#### GameVault (ERC4626)
- **Purpose:** Tokenized vault for protocol revenue and rewards
- **Features:**
  - Deposit assets to receive vault shares (shares = ERC20)
  - Withdraw vault shares to receive underlying assets
  - Fee accrual from AMM and other protocol modules
- **Key Functions:**
  - `deposit(uint256 assets)`: Deposit assets, receive vault shares
  - `withdraw(uint256 shares)`: Withdraw shares, receive assets
  - `totalAssets()`: Total assets under management

---

### 2. DeFi Core - Automated Market Maker (AMM)

#### ResourceAMM (Constant-Product Model)
- **Formula:** `x * y = k` (constant product)
- **Fee Structure:**
  - Trading fee: 0.3% on swaps (collected to protocol)
  - LP provider share: Proportional to liquidity pool stake
- **Pool Architecture:**
  - Separate pools for each resource pair
  - LP tokens represent ownership stake
  - Initial liquidity seeding via Uniswap V2 model
  
**Key Functions:**
- `swap(inputAmount, minOutputAmount)`: Execute swap with slippage protection
- `addLiquidity(amountA, amountB)`: Deposit liquidity, receive LP tokens
- `removeLiquidity(lpTokens)`: Burn LP tokens, withdraw liquidity
- `getReserves()`: Query current pool state

**Slippage Protection:**
- Maximum price impact validation
- Minimum output amount enforcement
- Reverts if swap exceeds user-specified slippage tolerance

---

### 3. Crafting Module - UUPS Upgradeable

#### Crafting (Proxy Pattern)
- **Implementation:** UUPS (Universal Upgradeable Proxy Standard)
- **Versions:** 
  - `CraftingV1.sol`: Initial implementation
  - `CraftingV2.sol`: Enhanced features (can be deployed via upgrade)
- **Recipe System:**
  - Admin-defined recipes: Input resources → Output items
  - Example: 5 wood + 3 stone → 1 iron sword
  - Crafting burns inputs, mints outputs
  - Cooldown periods per recipe (optional)

**Key Functions:**
- `addRecipe(id, inputs[], outputs[])`: Admin adds crafting recipe
- `craft(recipeId, quantity)`: Execute recipe, burn + mint
- `upgradeTo(address newImpl)`: Proxy upgrade path

**Event Tracking:**
- `ItemCrafted(player, recipeId, quantity, timestamp)`

---

### 4. Oracle Integration

#### ChainlinkPriceOracle
- **Purpose:** Fetch real-time asset prices with staleness checks
- **Data Source:** Chainlink Price Feeds
- **Safety Mechanisms:**
  - Staleness check: Max 1-hour delay tolerance
  - Revert on stale prices to prevent manipulation
  - Multi-feed redundancy (if available)

**Key Functions:**
- `getLatestPrice(feedAddress)`: Fetch current price + check staleness
- `priceWithTimestamp(feedAddress)`: Return (price, timestamp) tuple

**Use Cases:**
- Gaming: Convert real-world currency to in-game resources
- Valuation: Calculate player asset values for borrowing/lending

#### LootDrop (Chainlink VRF)
- **Purpose:** Verifiable randomness for loot drop generation
- **Integration:** Chainlink VRF V2.5
- **Mechanics:**
  - Request random number → Chainlink provides verified randomness
  - On-chain callback executes loot distribution
  - Mint randomized item rarity based on result

**Key Functions:**
- `requestLootDrop(quantity)`: Initiate VRF request
- `fulfillRandomWords(requestId, randomWords[])`: VRF callback, distribute loot

**Rarity Distribution:**
- Randomness → Rarity tier mapping (common → rare → epic → legendary)
- Probability tables configurable by DAO

---

### 5. Advanced Features

#### RentalVault
- **Purpose:** Rent rare ERC1155 items for temporary use
- **Rental Flow:**
  1. Owner lists item for rental (duration, price per day)
  2. Renter deposits collateral + rental fee
  3. Renter receives item for rental period
  4. Upon return: Collateral + rental fee returned
  5. Late return: Collateral slashed, item returned
  
**Key Functions:**
- `listForRental(itemId, durationDays, pricePerDay)`: List item
- `rentItem(rentalId, days, collateral)`: Initiate rental
- `returnItem(rentalId)`: Return rented item
- `settleExpired(rentalId)`: Handle expired rentals

#### ItemPoolFactory
- **Pattern:** CREATE2 factory for deterministic pool deployment
- **Purpose:** Create new trading pools for custom item pairs
- **Benefits:**
  - Deterministic addresses enable off-chain prediction
  - Reduced deployment cost via CREATE2
  - Dynamic pool ecosystem

**Key Functions:**
- `createPool(itemA, itemB, initialLiquidityA, initialLiquidityB)`: Deploy new pool
- `getPoolAddress(itemA, itemB)`: Predict pool address

#### YulUtils (Pure Yul Optimization)
- **Purpose:** Low-level math operations optimized in assembly
- **Functions:**
  - Efficient square root calculation
  - Bit manipulation utilities
  - Gas-optimized multiplications
- **Benefit:** Reduces gas cost for frequently called math operations

---

### 6. Governance & DAO

#### GameGovernor (OpenZeppelin Governor)
- **Voting Token:** GameToken (ERC20Votes)
- **Voting Mechanics:**
  - Proposal threshold: Min 1% of votes to propose
  - Voting period: 1 week
  - Vote type: For / Against / Abstain
  - Quorum: 4% minimum participation
  
**Governance Functions:**
- `propose(targets[], values[], calldatas[], description)`: Create proposal
- `castVote(proposalId, support)`: Vote on proposal
- `execute(...)`: Execute approved proposal via Timelock

#### GameTreasury (TimelockController)
- **Purpose:** 2-day execution delay for all governance decisions
- **Delay:** 48-hour timelock before proposal execution
- **Queue Management:**
  - Proposals queued after voting passes
  - Execute only after 2-day minimum
  - Emergency admin can cancel
  
**Controlled Parameters:**
- Resource drop rates
- Crafting recipe costs
- AMM trading fees
- Rental pricing rules
- Oracle price feed addresses

---

## Data Flow Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   GAMEFI PROTOCOL                        │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────┐                                        │
│  │  GameToken   │─────┐ (ERC20Votes + Permit)          │
│  │  (Gov Token) │     │                                 │
│  └──────────────┘     │                                 │
│                       │                                 │
│  ┌──────────────┐     │                                 │
│  │  GameItems   │────┐└─→ ┌──────────────────────┐     │
│  │  (ERC1155)   │    │    │  GOVERNANCE LAYER    │     │
│  └──────────────┘    │    │  GameGovernor +      │     │
│                      │    │  GameTreasury        │     │
│  ┌──────────────┐    │    │  (TimelockController)│     │
│  │  GameVault   │────┤    └──────────────────────┘     │
│  │  (ERC4626)   │    │                                 │
│  └──────────────┘    │                                 │
│          ▲           │                                 │
│          │           │                                 │
│  ┌──────────────────┘                                  │
│  │                                                     │
│  ├─→ ┌──────────────────┐                              │
│     │   ResourceAMM     │ (Constant-Product)           │
│     │   (Swaps, LPs)    │                              │
│     └──────────────────┘                               │
│           ▲                                             │
│           │                                             │
│     ┌─────┴──────────────┐                              │
│     │                    │                              │
│  ┌──────────┐    ┌──────────────┐                       │
│  │ Crafting │    │ LootDrop     │                       │
│  │ (UUPS)   │    │ (VRF)        │                       │
│  └──────────┘    └──────────────┘                       │
│     ▲                    ▲                               │
│     │                    │                              │
│  ┌──────────┐    ┌──────────────┐                       │
│  │Resources │    │ Randomness   │                       │
│  │  (burn)  │    │ (Chainlink)   │                       │
│  └──────────┘    └──────────────┘                       │
│                                                         │
│  ┌──────────────────┐         ┌─────────────────┐      │
│  │  RentalVault     │         │ ItemPoolFactory │      │
│  │  (Rentals)       │         │ (CREATE2)       │      │
│  └──────────────────┘         └─────────────────┘      │
│                                                         │
│  ┌──────────────────┐         ┌─────────────────┐      │
│  │ ChainlinkPrice   │         │ YulUtils        │      │
│  │ Oracle (Feed)    │         │ (Assembly)      │      │
│  └──────────────────┘         └─────────────────┘      │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Contract Dependency Graph

```
GameToken (independent, base)
    ↓
GameGovernor (uses GameToken for voting)
    ↓
GameTreasury (uses Governor for authorization)
    ↓
┌──────────────────────────────────────┐
│  Core Economic Components            │
├──────────────────────────────────────┤
│                                      │
├─ GameItems (independent)            │
├─ GameVault (uses GameItems)         │
├─ ResourceAMM (uses GameItems)       │
├─ Crafting (uses GameItems)          │
├─ LootDrop (uses GameItems + VRF)    │
├─ RentalVault (uses GameItems)       │
│                                      │
└──────────────────────────────────────┘
    ↓
├─ ChainlinkPriceOracle (Oracle feed)
├─ ItemPoolFactory (CREATE2 deployment)
└─ YulUtils (Pure Yul optimization)
```

---

## Deployment Architecture

### Layer 1: Token & Governance
1. Deploy `GameToken`
2. Deploy `GameGovernor` (connected to GameToken)
3. Deploy `GameTreasury` with 2-day delay

### Layer 2: Economic Core
4. Deploy `GameItems` (ERC1155)
5. Deploy `GameVault` (ERC4626, uses GameItems)
6. Deploy `ResourceAMM` (uses GameItems for pools)

### Layer 3: Advanced Features
7. Deploy `Crafting` with UUPS proxy
8. Deploy `LootDrop` (Chainlink VRF)
9. Deploy `RentalVault` (uses GameItems)
10. Deploy `ItemPoolFactory` (CREATE2 factory)

### Layer 4: Oracles & Utils
11. Deploy `ChainlinkPriceOracle`
12. Deploy `YulUtils` (library)

### Layer 5: Indexing & Frontend
13. Deploy The Graph subgraph
14. Deploy React dApp frontend

### L2 Deployment
15. Deploy all contracts to Base Sepolia / Arbitrum Sepolia
16. Verify on block explorers

---

## Event Logging & Indexing

### Core Events for The Graph

| Contract | Event | Indexed Fields | Use Case |
|----------|-------|----------------|----------|
| ResourceAMM | `ResourceSwapped` | (trader, inputToken, outputToken, amount) | Trade history |
| Crafting | `ItemCrafted` | (player, recipeId, quantity, timestamp) | Crafting tracking |
| RentalVault | `ItemRented` | (renter, tokenId, duration, rentalId) | Rental history |
| RentalVault | `RentalReturned` | (renter, tokenId, rentalId) | Return tracking |
| LootDrop | `LootDropped` | (player, itemId, rarity, vrfRequestId) | Reward history |
| GameGovernor | `ProposalCreated` | (proposalId, proposer, startBlock, endBlock) | Governance |
| GameGovernor | `VoteCast` | (voter, proposalId, support, reason) | Vote tracking |

### Subgraph Schema (5+ Entities)
- `User`: Player accounts and holdings
- `Swap`: AMM trading events
- `CraftingEvent`: Item crafting history
- `RentalEvent`: Item rental transactions
- `LootDropEvent`: Loot drop distribution
- `Proposal`: DAO governance proposals
- `Vote`: Individual votes on proposals

---

## Security Considerations

1. **Oracle Staleness:** Chainlink price feeds checked for max 1-hour staleness
2. **VRF Security:** Chainlink VRF provides cryptographic randomness
3. **Reentrancy Protection:** All external calls protected via CEI pattern
4. **Upgrade Safety:** UUPS proxy with proper access controls
5. **Slippage Protection:** AMM enforces minimum output on swaps
6. **Access Control:** Role-based permissions for admin functions
7. **Time Locks:** 2-day governance delay prevents flash attacks

---

## Testing Strategy

| Test File | Coverage |
|-----------|----------|
| `AdvancedContracts.t.sol` | Vault, Loot, Rental, Oracle tests |
| `Crafting.t.sol` | Crafting recipes & item minting |
| `CraftingUpgrade.t.sol` | UUPS proxy upgrade flow |
| `Governance.t.sol` | Governor voting & proposals |
| `ResourceAMM.t.sol` | Swaps, liquidity, edge cases |

**Test Types:**
- Unit tests: Function behavior
- Fuzz tests: Random input coverage
- Invariant tests: Protocol invariants
- Fork tests: Mainnet integration

---

## Performance & Scalability

- **Gas Optimization:** YulUtils for low-level math
- **L2 Deployment:** Reduced costs via Arbitrum/Base
- **Batch Operations:** ERC1155 batch minting/burning
- **Factory Pattern:** CREATE2 for efficient deployments

---

## Conclusion

The GameFi Economy Protocol provides a modular, upgradeable, and secure foundation for decentralized gaming economies. With integrated oracle support, AMM trading, governance, and rental systems, it enables complex on-chain game mechanics while maintaining security and scalability.
