# One-Page Proposal: GameFi Economy Protocol

## Scenario

Option B - GameFi Economy.

The project is not a full game. It is a production-style decentralized economy layer for a game: resources, items, crafting, resource swaps, item rentals, loot drops, and DAO-governed parameters.

## Core Idea

Players interact with ERC1155 resources and items. They can receive resources, craft equipment, trade fungible resources through a constant-product AMM, rent rare items, and participate in governance through an ERC20Votes token. The DAO controls economic parameters such as drop rates, crafting costs, accepted rental assets, protocol fees, and treasury settings through a Timelock.

## Initial MVP Scope

- `GameToken`: governance token using ERC20Votes and ERC20Permit.
- `GameItems`: ERC1155 contract for resources and in-game items.
- `GameVault`: ERC4626 vault for protocol fees and reward assets.
- Custom AMM for resource swaps with 0.3% fee, slippage protection, and LP tokens.
- Crafting module that burns resources and mints crafted items.
- Loot drop module using Chainlink VRF with mocks for tests.
- Rental vault for rare ERC1155 items.
- Governor + TimelockController for parameter changes.
- Subgraph indexing swaps, crafting, rentals, loot drops, and governance activity.
- React frontend for wallet connection, balances, swaps/crafting, vault deposits, and voting.

## Team Ownership Draft

- Smart contracts and tests: token standards, AMM, crafting, vault, security checks.
- Governance, deployment, and DevOps: Governor, Timelock, L2 scripts, CI, verification.
- Frontend, subgraph, and documentation: dApp, indexed data views, diagrams, audit report, presentation.

## Why This Scenario

Option B gives a clear demo story while still covering every mandatory technical requirement. The project can stay compact by focusing on the economy protocol instead of building game graphics or off-chain gameplay.

## Mandatory Requirement Mapping

- Advanced Solidity: UUPS upgradeable crafting module, CREATE/CREATE2 factory, Yul math benchmark.
- Token standards: ERC20Votes + ERC20Permit governance token, ERC1155 game items, ERC4626 vault.
- DeFi primitive: custom constant-product AMM.
- Oracles: Chainlink VRF for loot drops and Chainlink price feed with staleness checks for asset valuation.
- Governance: OpenZeppelin Governor + 2-day TimelockController.
- Indexing: The Graph subgraph with at least 4 entities and documented GraphQL queries.
- L2: deployment and verification on an L2 testnet such as Base Sepolia or Arbitrum Sepolia.

