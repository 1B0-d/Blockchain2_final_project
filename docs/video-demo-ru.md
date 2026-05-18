# Video Demo Script (RU)

## 1. Вступление

Это финальный проект по Blockchain Technologies 2: GameFi Economy Protocol.
Мы выбрали Option B: on-chain экономику для игры.

Протокол состоит из:

- `GameToken` - ERC20Votes + ERC20Permit governance token.
- `GameItems` - ERC1155 ресурсы и игровые предметы.
- `GameVault` - ERC4626 vault для GAME токенов.
- `ResourceAMM` - constant-product AMM для обмена ресурсов WOOD/IRON.
- `Crafting` - UUPS upgradeable crafting system.
- `GameGovernor` + `TimelockController` - DAO governance.
- `LootDrop`, `RentalVault`, `ChainlinkPriceOracle`, `ItemPoolFactory`, `YulUtils` - дополнительные требования проекта.

## 2. Что показать в коде

Показать файлы:

- `contracts/GameToken.sol`
- `contracts/GameItems.sol`
- `contracts/ResourceAMM.sol`
- `contracts/Crafting.sol`
- `contracts/GameGovernor.sol`
- `script/Deploy.s.sol`
- `script/DemoSetup.s.sol`
- `frontend/src/lib/contracts.ts`

Сказать:

Контракты покрывают основные требования: ERC20Votes/ERC20Permit, ERC1155, ERC4626,
UUPS proxy, CREATE2 factory, inline Yul, AMM, oracle integration, governance and subgraph.

## 3. Если фронт показывает ошибку

Сказать честно:

Сейчас фронтенд ожидает реальные адреса задеплоенных контрактов.
Если в `frontend/src/lib/contracts.ts` стоят адреса вида `0x000...001`,
это placeholder addresses. Они нужны только как временная заглушка до деплоя.

Поэтому ошибка `could not decode result data` нормальна: браузер вызывает `allowance()`
у адреса, где нет ERC20-контракта.

Чтобы фронт работал полностью, нужно:

1. Задеплоить контракты на L2 testnet.
2. Скопировать адреса из output деплоя.
3. Заменить placeholders в `frontend/src/lib/contracts.ts`.
4. Запустить demo setup, чтобы у аккаунта были ресурсы и у AMM была ликвидность.
5. Подключить MetaMask к той же сети.

## 4. Важный момент по сети

Фронт сейчас hardcoded на Base Sepolia, chain id `84532`.
Если `.env` использует Arbitrum Sepolia RPC, chain id `421614`, то есть два варианта:

1. Перейти полностью на Base Sepolia: поставить Base RPC в `.env`, получить Base Sepolia ETH, деплоить туда.
2. Перейти полностью на Arbitrum Sepolia: оставить текущий RPC, но поменять frontend network config на Arbitrum Sepolia.

Главное правило: MetaMask, `.env RPC_URL`, deploy output и `contracts.ts` должны быть в одной сети.

## 5. Команды для реального демо

Сначала проверить сборку:

```bash
npm --prefix frontend run build
forge build
forge test
```

Затем деплой:

```bash
forge script script/Deploy.s.sol:Deploy --rpc-url $RPC_URL --broadcast -vvvv
```

После деплоя добавить адреса в `.env`:

```bash
GAME_ITEMS_ADDRESS=...
CRAFTING_ADDRESS=...
RESOURCE_AMM_ADDRESS=...
```

Запустить demo setup:

```bash
forge script script/DemoSetup.s.sol:DemoSetup --rpc-url $RPC_URL --broadcast -vvvv
```

Потом заменить адреса в `frontend/src/lib/contracts.ts`:

```ts
GameToken: "0x...",
GameItems: "0x...",
GameVault: "0x...",
ResourceAMM: "0x...",
Crafting: "0x...",
GameGovernor: "0x...",
```

И запустить фронт:

```bash
npm --prefix frontend run dev
```

## 6. Что показать в UI

1. Подключить MetaMask.
2. Показать правильную сеть.
3. Открыть Swap: показать WOOD/IRON balances and pool reserves.
4. Сделать swap WOOD -> IRON.
5. Открыть Craft & Vault.
6. Сделать craft recipe: `3 WOOD + 2 IRON -> 1 SWORD`.
7. В Vault показать GAME balance и deposit GAME.
8. В Governance показать voting power и delegate.

## 7. Короткий текст для видео

В этом демо я показываю GameFi Economy Protocol - модульную on-chain экономику
для игры. Проект реализует ERC20 governance token, ERC1155 игровые ресурсы,
ERC4626 vault, AMM для обмена ресурсов, upgradeable crafting через UUPS,
DAO governance через Governor и Timelock, а также дополнительные модули для loot,
rentals, oracle и subgraph indexing.

Фронтенд подключается к MetaMask, проверяет сеть, читает балансы и состояние
контрактов, и вызывает state-changing функции: swap, deposit, delegate/vote.
После деплоя реальные адреса контрактов вставляются в `frontend/src/lib/contracts.ts`.
Для демо также запускается setup script, который добавляет рецепт, ресурсы и
ликвидность AMM.
