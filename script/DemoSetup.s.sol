// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console2 } from "forge-std/Script.sol";

import { CraftingV1 } from "../contracts/Crafting.sol";
import { GameItems } from "../contracts/GameItems.sol";
import { ResourceAMM } from "../contracts/ResourceAMM.sol";

/// @notice Seeds a freshly deployed testnet deployment with data for a video demo.
/// @dev Requires GAME_ITEMS_ADDRESS, CRAFTING_ADDRESS, and RESOURCE_AMM_ADDRESS in .env.
contract DemoSetup is Script {
    uint256 private constant TARGET_PLAYER_RESOURCE_BALANCE = 10_000;
    uint256 private constant TARGET_DEPLOYER_RESOURCE_BALANCE = 6_000;
    uint256 private constant INITIAL_LIQUIDITY = 5_000;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        address demoPlayer = deployer;
        if (vm.envExists("DEMO_PLAYER_ADDRESS")) {
            demoPlayer = vm.envAddress("DEMO_PLAYER_ADDRESS");
        }

        GameItems items = GameItems(vm.envAddress("GAME_ITEMS_ADDRESS"));
        CraftingV1 crafting = CraftingV1(vm.envAddress("CRAFTING_ADDRESS"));
        ResourceAMM amm = ResourceAMM(vm.envAddress("RESOURCE_AMM_ADDRESS"));

        uint256 wood = items.WOOD();
        uint256 iron = items.IRON();
        uint256 sword = items.SWORD();

        vm.startBroadcast(deployerKey);

        _topUp(items, demoPlayer, wood, TARGET_PLAYER_RESOURCE_BALANCE);
        _topUp(items, demoPlayer, iron, TARGET_PLAYER_RESOURCE_BALANCE);

        if (amm.totalShares() == 0) {
            _topUp(items, deployer, wood, TARGET_DEPLOYER_RESOURCE_BALANCE);
            _topUp(items, deployer, iron, TARGET_DEPLOYER_RESOURCE_BALANCE);
            items.setApprovalForAll(address(amm), true);
            amm.addLiquidity(INITIAL_LIQUIDITY, INITIAL_LIQUIDITY, 0);
        }

        if (crafting.nextRecipeId() == 0) {
            CraftingV1.Ingredient[] memory ingredients = new CraftingV1.Ingredient[](2);
            ingredients[0] = CraftingV1.Ingredient({ itemId: wood, amount: 3 });
            ingredients[1] = CraftingV1.Ingredient({ itemId: iron, amount: 2 });
            crafting.addRecipe(ingredients, sword, 1);
        }

        vm.stopBroadcast();

        console2.log("Demo player:", demoPlayer);
        console2.log("Demo setup complete");
    }

    function _topUp(GameItems items, address account, uint256 itemId, uint256 targetBalance)
        private
    {
        uint256 current = items.balanceOf(account, itemId);
        if (current < targetBalance) {
            items.mint(account, itemId, targetBalance - current, "");
        }
    }
}
