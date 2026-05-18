# GameFi Protocol - Speaker Script RU

## Как делим на 3 человека

### Speaker 1 - Smart Contracts / Architecture

Слайды: 1-5.

Что сказать:

```text
This is our GameFi Economy Protocol for Blockchain Technologies 2.
We chose Option B: a blockchain game economy.

The protocol is not a full game. It is an on-chain economy layer:
players own ERC1155 resources, swap resources through an AMM,
craft items, deposit GAME into a vault, and govern parameters through a DAO.

Core contracts:
GameToken is ERC20Votes and ERC20Permit.
GameItems is ERC1155 for resources and crafted items.
GameVault is ERC4626.
ResourceAMM is our custom constant-product AMM.
Crafting is UUPS upgradeable and deployed behind an ERC1967 proxy.
```

Demo phrase:

```text
For the live demo we focus on resource swap and crafting because these actions
show real wallet transactions against deployed contracts.
```

## Speaker 2 - Governance / Advanced / Tests

Слайды: 6-9.

Что сказать:

```text
The governance stack uses OpenZeppelin Governor and TimelockController.
Voting power comes from GAME token checkpoints through ERC20Votes.
The governance parameters are: 1 day voting delay, 1 week voting period,
4 percent quorum, 1 percent proposal threshold, and 2 day timelock delay.

For advanced requirements we implemented UUPS upgradeability,
CREATE and CREATE2 factory deployment, Yul assembly utilities,
Chainlink price feed integration with staleness checks,
and a The Graph subgraph schema for protocol events.

The test suite includes unit, fuzz, invariant and optional fork tests.
The latest local snapshot in the repo shows 87 passed, 0 failed, 3 skipped.
```

Deployment phrase:

```text
Contracts are deployed on Arbitrum Sepolia, chain id 421614.
The frontend uses addresses copied from Foundry broadcast output.
For Crafting we use the ERC1967Proxy address, not the implementation address.
```

## Speaker 3 - Frontend / Live Demo

Слайды: 10-12.

Что сказать:

```text
The frontend is a React/Vite dApp using ethers.js and MetaMask.
It detects the active wallet network and prompts the user to switch to
Arbitrum Sepolia if needed.

Here we can see my connected wallet, resource balances, and AMM pool reserves.
These values are read from deployed contracts, not mocked.
```

Live demo steps:

```text
1. Show green "Arbitrum Sepolia" badge.
2. Show WOOD and IRON balances.
3. Swap a small amount, like 1 or 2.
4. Open Craft & Vault -> Crafting.
5. Show recipe #0: 3 WOOD + 2 IRON -> 1 SWORD.
6. Click Craft Item and confirm in MetaMask.
```

If gas fails:

```text
The transaction can fail if MetaMask sets max fee below the current block base fee.
The contracts and frontend are already connected; the fix is to increase gas
in MetaMask or retry with the gas bump added in the frontend.
```

Vault note:

```text
Vault is connected, but for this demo we avoid depositing unless the demo wallet
has GAME tokens. Swap and Craft are the safest live flows.
```

## Quick Team Message

```text
Network: Arbitrum Sepolia, chain id 421614.
Use these demo flows: Swap and Craft.
Do not use Base Sepolia.
Do not use the CraftingV1 implementation address in frontend.
Use ERC1967Proxy:
0x9d2b2608cd9cb1abfe026f5800d5f0f6f5cf427b

If MetaMask gas fails, retry and set max fee higher.
```
