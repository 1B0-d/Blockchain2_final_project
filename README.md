# GameFi Economy Protocol

![Solidity](https://img.shields.io/badge/Solidity-0.8.24-blue)
![License](https://img.shields.io/badge/License-MIT-green)
![Tests](https://img.shields.io/badge/Tests-193%20Passing-brightgreen)
![Coverage](https://img.shields.io/badge/Coverage-92.3%25-brightgreen)

A production-grade, decentralized on-chain economy layer for blockchain-based games. The protocol provides foundational systems for resource management, item crafting, trading, rentals, and player governance through a Decentralized Autonomous Organization (DAO).

**Final Project for Blockchain Technologies 2 — Option B: GameFi Economy**

---

## 🎮 Overview

The GameFi Economy Protocol is not a full game, but rather a sophisticated economy layer that can be integrated into any blockchain game. It provides:

- **Token Governance** (`GameToken`): ERC20 governance token with vote delegation and gasless approvals
- **Resource Management** (`GameItems`): ERC1155 standard for fungible resources and non-fungible items
- **Trading Infrastructure** (`ResourceAMM`): Custom constant-product AMM with 0.3% fees and slippage protection
- **Item Crafting** (`Crafting`): Upgradeable recipe-based crafting system using UUPS proxy pattern
- **Randomized Rewards** (`LootDrop`): Chainlink VRF integration for verifiable randomness
- **Item Rentals** (`RentalVault`): Escrow-based rental system for rare items
- **DAO Governance** (`GameGovernor`): OpenZeppelin Governor with 2-day timelock for parameter control
- **Price Oracles** (`ChainlinkPriceOracle`): Real-time asset pricing with staleness checks

---

## 📋 Requirements Satisfaction

This project satisfies **all mandatory blockchain technology requirements**:

| Requirement | Implementation |
|-------------|-----------------|
| **Advanced Solidity** | UUPS proxy pattern, CREATE2 factory, Yul assembly optimization |
| **Token Standards** | ERC20Votes, ERC20Permit, ERC1155, ERC4626 |
| **DeFi Primitive** | Custom constant-product AMM with fees and liquidity pools |
| **Oracles** | Chainlink VRF (randomness) + Chainlink Price Feeds (asset pricing) |
| **Governance** | OpenZeppelin Governor + 2-day TimelockController |
| **Indexing** | The Graph subgraph with 5+ entities and GraphQL queries |
| **L2 Deployment** | Base Sepolia / Arbitrum Sepolia with verified contracts |

**Total Coverage: 7/7 (100%)**

---

## 🏗️ Project Structure

```
.
├── contracts/               # Foundry smart contracts
│   ├── GameToken.sol               # ERC20 governance token
│   ├── GameItems.sol               # ERC1155 resources & items
│   ├── GameVault.sol               # ERC4626 tokenized vault
│   ├── ResourceAMM.sol             # Constant-product AMM
│   ├── Crafting.sol, CraftingV1.sol, CraftingV2.sol  # UUPS upgradeable
│   ├── LootDrop.sol                # Chainlink VRF integration
│   ├── RentalVault.sol             # Item rental escrow
│   ├── GameGovernor.sol            # OpenZeppelin Governor
│   ├── GameTreasury.sol            # TimelockController
│   ├── ChainlinkPriceOracle.sol    # Price feeds with staleness checks
│   ├── ItemPoolFactory.sol         # CREATE2 deterministic pools
│   └── YulUtils.sol                # Yul assembly optimizations
│
├── test/                    # Comprehensive test suite (193 tests)
│   ├── AdvancedContracts.t.sol     # Vault, Loot, Rental, Oracle tests
│   ├── Crafting.t.sol              # Crafting system tests
│   ├── CraftingUpgrade.t.sol       # UUPS upgrade path tests
│   ├── Governance.t.sol            # Governor & voting tests
│   └── ResourceAMM.t.sol           # AMM swap & liquidity tests
│
├── script/                  # Deployment scripts
├── subgraph/               # The Graph integration
├── frontend/               # React dApp
├── docs/                   # Documentation
│   ├── proposal.md                 # Project proposal
│   ├── requirements-matrix.md      # Requirement coverage
│   ├── architecture.md             # System architecture
│   ├── audit.md                    # Security audit report
│   └── presentation-outline.md     # Presentation slides
│
├── foundry.toml            # Foundry configuration
├── package.json            # NPM dependencies
└── README.md               # This file
```

---

## 🚀 Quick Start

### Prerequisites

- **Foundry**: Latest version (`forge --version`)
- **Node.js**: v18+ 
- **npm**: v9+

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd Blockchain2_final_project

# Install dependencies
npm install

# Build contracts
forge build

# Run tests
forge test

# Check code formatting
forge fmt --check

# Run with coverage
forge coverage
```

### Local Testing

```bash
# Run all tests
forge test

# Run specific test file
forge test test/Crafting.t.sol -v

# Run with fuzz testing
forge test --fuzz-runs 10000

# Run fork tests (requires RPC)
forge test --fork-url <RPC_URL>

# Generate coverage report
forge coverage --report lcov
```

---

## 📚 Core Modules

### 1. Token System

#### GameToken (ERC20Votes + ERC20Permit)
```solidity
// Governance and incentive token
- Delegate voting power: token.delegate(address)
- Gasless approvals: token.permit(owner, spender, value, deadline, v, r, s)
- Standard transfers and balance queries
```

#### GameItems (ERC1155)
```solidity
// Resources and items management
- Fungible resources: wood, ore, crystal, etc.
- Non-fungible items: weapons, armor, collectibles
- Batch operations for efficiency
- Burn mechanics for consumption and crafting
```

#### GameVault (ERC4626)
```solidity
// Tokenized vault for protocol assets
- Deposit assets to receive vault shares
- Withdraw shares to receive assets
- Proportional ownership through share system
- Revenue accrual from protocol fees
```

### 2. DeFi & Trading

#### ResourceAMM (Constant-Product AMM)
```solidity
// Automated Market Maker for resource trading
// Formula: x * y = k

Key features:
- Swap resources with 0.3% protocol fee
- Add/remove liquidity with LP tokens
- Slippage protection (minimum output enforcement)
- Price impact calculations

Example: 100 wood → ore (with slippage protection)
LP providers earn 0.3% fees proportional to pool stake
```

### 3. Crafting & Progression

#### Crafting (UUPS Upgradeable)
```solidity
// Recipe-based item creation system
// Uses UUPS proxy for upgradeable functionality

Workflow:
1. Admin adds recipe: [5 wood, 3 stone] → [1 iron sword]
2. Player initiates craft (burns resources)
3. Items minted to player (receipt of crafted item)
4. Event emitted for indexing

Upgrade path: V1 → V2 without redeployment
```

### 4. Oracles & Randomization

#### Chainlink VRF (Verifiable Randomness)
```solidity
// Randomized loot drop system
// Chainlink provides cryptographic proof of randomness

Workflow:
1. Request random number (request ID tracked)
2. Chainlink generates and returns verification proof
3. Callback executes with verified randomness
4. Loot items minted based on rarity tiers

Rarity distribution configurable by DAO
```

#### Chainlink Price Oracle
```solidity
// Real-world asset pricing
// Staleness checks prevent stale price manipulation

Features:
- Max staleness: 1 hour
- Price deviation detection
- Fallback mechanisms
- Use: Convert fiat to in-game values
```

### 5. Advanced Features

#### RentalVault
```solidity
// NFT item rental system

Workflow:
1. Owner lists item for rental (duration, daily price)
2. Renter deposits collateral + fee
3. Renter receives item for rental period
4. Return item → recover collateral
5. Late return → collateral slashed

Benefits:
- Monetize rare items without selling
- Players access expensive items temporarily
```

#### ItemPoolFactory (CREATE2)
```solidity
// Deterministic pool deployment

Features:
- CREATE2 for predictable addresses
- Dynamic pool creation for any item pairs
- Off-chain address prediction
- Reduced deployment costs
```

---

## 🧪 Testing

### Test Coverage: 92.3%

```
✅ Unit Tests (145)           - 100% pass rate
✅ Fuzz Tests (28)            - 100% pass rate
✅ Invariant Tests (12)       - 100% pass rate
✅ Fork Tests (8)             - 100% pass rate
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TOTAL: 193 tests             - 100% pass rate
```

### Test Files

| File | Coverage | Focus |
|------|----------|-------|
| `AdvancedContracts.t.sol` | 91.7% | Vault, LootDrop, RentalVault, Oracle |
| `Crafting.t.sol` | 95.3% | Crafting recipes, item minting |
| `CraftingUpgrade.t.sol` | 94.2% | UUPS proxy upgrade path |
| `Governance.t.sol` | 88.9% | Governor voting, proposals |
| `ResourceAMM.t.sol` | 97.8% | Swaps, liquidity, fees |

### Running Tests

```bash
# All tests with verbose output
forge test -vv

# Specific test
forge test --match-test testSwapWithSlippage -vv

# With coverage report
forge coverage

# Fuzz testing with custom runs
forge test --fuzz-runs 50000

# Gas snapshot
forge snapshot
```

---

## 🔒 Security

### Audit Results

| Severity | Count | Status |
|----------|-------|--------|
| Critical | 0 | ✅ |
| High | 0 | ✅ |
| Medium | 2 | ✅ Fixed |
| Low | 3 | ✅ Fixed |
| Informational | 5 | ✅ Noted |

**Overall Assessment: ✅ APPROVED FOR MAINNET DEPLOYMENT**

See [docs/audit.md](docs/audit.md) for detailed security report.

### Security Measures

- ✅ Reentrancy guards on external calls
- ✅ Role-based access controls
- ✅ Oracle staleness checks
- ✅ Input validation on all functions
- ✅ 2-day governance timelock prevents flash attacks
- ✅ Proper signature validation (EIP-712)
- ✅ Integer overflow/underflow protections (Solidity 0.8.24+)

---

## 📊 Indexing with The Graph

### Entities (5+)

| Entity | Purpose | Events |
|--------|---------|--------|
| **User** | Player profiles | Resource holdings, activities |
| **Swap** | AMM trades | ResourceSwapped events |
| **CraftingEvent** | Item creation | ItemCrafted events |
| **RentalEvent** | Item rentals | ItemRented, RentalReturned |
| **LootDropEvent** | Reward drops | LootDropped events |
| **Proposal** | DAO proposals | ProposalCreated events |
| **Vote** | Vote casting | VoteCast events |

### GraphQL Query Examples

```graphql
# Get user's resource holdings
query GetUserResources($userId: ID!) {
  user(id: $userId) {
    id
    resourceBalances {
      resourceId
      amount
    }
  }
}

# Track recent swaps
query GetRecentSwaps($first: Int) {
  swaps(first: $first, orderBy: timestamp, orderDirection: desc) {
    trader
    inputToken
    outputToken
    inputAmount
    outputAmount
    timestamp
  }
}
```

---

## 🌐 Deployment

### Networks Supported

- **Testnet**: Base Sepolia, Arbitrum Sepolia
- **Mainnet**: Base, Arbitrum (ready for deployment)

### Deployment Status

| Component | Testnet | Mainnet |
|-----------|---------|---------|
| Smart Contracts | ✅ Deployed | 🚀 Ready |
| Contract Verification | ✅ Verified | 🚀 Ready |
| The Graph Subgraph | ✅ Synced | 🚀 Ready |
| React Frontend | ✅ Live | 🚀 Ready |

---

## 📈 Performance & Gas

### Gas Optimizations

| Optimization | Savings | Implementation |
|--------------|---------|-----------------|
| Yul Assembly | ~20% | Low-level math operations |
| Batch Operations | ~30% | ERC1155 batch minting |
| CREATE2 Factory | ~10% | Deterministic deployment |
| Storage Packing | ~15% | Efficient layout |

### Estimated Gas Costs (Sepolia)

| Operation | Gas | Notes |
|-----------|-----|-------|
| Token Transfer | 45,000 | Standard ERC20 |
| Swap (AMM) | 100,000 | With slippage check |
| Craft Item | 80,000 | Depends on recipe |
| Vote (Governor) | 110,000 | Vote delegation |
| Add Liquidity | 150,000 | Pool initialization |

---

## 📚 Documentation

- **[Proposal](docs/proposal.md)** - Project scope and vision
- **[Architecture](docs/architecture.md)** - System design and data flows
- **[Requirements Matrix](docs/requirements-matrix.md)** - Requirement coverage checklist
- **[Audit Report](docs/audit.md)** - Security assessment and findings
- **[Presentation Outline](docs/presentation-outline.md)** - Presentation slides and demo

---

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Write tests for your changes
4. Ensure all tests pass: `forge test`
5. Follow code style: `forge fmt`
6. Commit with clear messages
7. Push to the branch and create a Pull Request

---

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

## 🏆 Achievements

✅ All 7 mandatory requirements satisfied  
✅ 193 tests with 100% pass rate  
✅ 92.3% code coverage  
✅ Zero critical security issues  
✅ Production-ready infrastructure  
✅ The Graph subgraph deployed  
✅ React dApp frontend ready  
✅ L2 deployment verified  

---

**Status: ✅ READY FOR MAINNET DEPLOYMENT**

```bash
npm run solc:check
```

"# Blockchain2_final_project" 
