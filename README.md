# GameFi Economy Protocol

Final project for Blockchain Technologies 2, Option B: GameFi Economy.

The protocol models a compact on-chain game economy:

- `GameToken`: ERC20 governance token with `ERC20Votes` and `ERC20Permit`.
- `GameItems`: ERC1155 resources and in-game items.
- `GameVault`: ERC4626 tokenized vault for protocol fees / reward assets.

Planned modules:

- constant-product AMM for fungible resources;
- crafting system;
- Chainlink VRF loot drops;
- NFT / item rental vault;
- OpenZeppelin Governor + TimelockController;
- The Graph subgraph;
- React dApp;
- L2 deployment and verification.

## Project Structure

```text
contracts/      Foundry smart contracts
test/           unit, fuzz, invariant, and fork tests
script/         deployment and post-deployment verification scripts
frontend/       React dApp
subgraph/       The Graph schema, mappings, and subgraph.yaml
docs/           proposal, architecture, audit, gas, and coverage reports
.github/        CI workflows
```

## Local Setup

Install dependencies:

```bash
npm install
```

After Foundry is installed:

```bash
forge build
forge test
forge fmt --check
```

Until Foundry is installed on this machine, the starter contracts can be checked with:

```bash
npm run solc:check
```

"# Blockchain2_final_project" 
