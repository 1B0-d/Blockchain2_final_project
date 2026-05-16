// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { GameItems }    from "../contracts/GameItems.sol";
import { CraftingV1 }   from "../contracts/CraftingV1.sol";
import { CraftingV2 }   from "../contracts/CraftingV2.sol";

/// @title CraftingUpgradeTest
/// @notice Demonstrates UUPS upgrade lifecycle:
///         deploy proxy → use V1 → upgrade to V2 → V1 state preserved → V2 features work.
contract CraftingUpgradeTest is Test {
    GameItems items;
    CraftingV1 proxy; // typed as V1 for V1 calls, recast to V2 after upgrade

    address admin = makeAddr("admin");
    address alice = makeAddr("alice");

    uint256 constant WOOD  = 1;
    uint256 constant IRON  = 2;
    uint256 constant SWORD = 100;

    function setUp() public {
        vm.startPrank(admin);
        items = new GameItems("ipfs://", admin);

        // Deploy V1 implementation
        CraftingV1 implV1 = new CraftingV1();

        // Deploy ERC1967Proxy pointing at V1
        bytes memory initData = abi.encodeCall(CraftingV1.initialize, (address(items), admin));
        ERC1967Proxy proxyContract = new ERC1967Proxy(address(implV1), initData);

        // Cast proxy address to CraftingV1 for interaction
        proxy = CraftingV1(address(proxyContract));

        // Grant roles on items to the proxy
        items.grantRole(items.MINTER_ROLE(),      address(proxy));
        items.grantRole(items.GAME_SYSTEM_ROLE(), address(proxy));

        vm.stopPrank();
    }

    // ── V1 baseline tests ────────────────────────────────────────────────────

    function test_v1_version() public view {
        assertEq(proxy.version(), "V1");
    }

    function test_v1_add_and_craft() public {
        CraftingV1.Ingredient[] memory ing = new CraftingV1.Ingredient[](2);
        ing[0] = CraftingV1.Ingredient({ itemId: WOOD, amount: 2 });
        ing[1] = CraftingV1.Ingredient({ itemId: IRON, amount: 1 });

        vm.prank(admin);
        uint256 recipeId = proxy.addRecipe(ing, SWORD, 1);

        // Give alice resources and approve
        vm.startPrank(admin);
        items.mint(alice, WOOD, 10, "");
        items.mint(alice, IRON, 10, "");
        vm.stopPrank();
        vm.prank(alice); items.setApprovalForAll(address(proxy), true);

        vm.prank(alice);
        proxy.craft(recipeId);

        assertEq(items.balanceOf(alice, SWORD), 1);
    }

    // ── Upgrade to V2 ────────────────────────────────────────────────────────

    function test_upgrade_v1_to_v2_preserves_state() public {
        // Add a recipe on V1
        CraftingV1.Ingredient[] memory ing = new CraftingV1.Ingredient[](1);
        ing[0] = CraftingV1.Ingredient({ itemId: WOOD, amount: 1 });
        vm.prank(admin);
        uint256 recipeId = proxy.addRecipe(ing, SWORD, 1);

        assertEq(proxy.nextRecipeId(), 1, "V1: 1 recipe stored");

        // Deploy V2 implementation
        CraftingV2 implV2 = new CraftingV2();

        // Upgrade (only UPGRADER_ROLE — held by admin)
        vm.prank(admin);
        proxy.upgradeToAndCall(address(implV2), "");

        // Cast proxy to V2
        CraftingV2 proxyV2 = CraftingV2(address(proxy));

        // State preserved: nextRecipeId still 1
        assertEq(proxyV2.nextRecipeId(), 1, "V2: recipe count preserved");

        // V2 version string
        assertEq(proxyV2.version(), "V2");

        // Recipe from V1 still readable
        (,, uint256 outAmt, bool active) = proxyV2.getRecipe(recipeId);
        assertEq(outAmt, 1);
        assertTrue(active);
    }

    function test_upgrade_v2_xp_feature() public {
        // Start on V2
        CraftingV2 implV2 = new CraftingV2();
        vm.prank(admin);
        proxy.upgradeToAndCall(address(implV2), "");
        CraftingV2 proxyV2 = CraftingV2(address(proxy));

        // Add recipe and set XP
        CraftingV1.Ingredient[] memory ing = new CraftingV1.Ingredient[](1);
        ing[0] = CraftingV1.Ingredient({ itemId: WOOD, amount: 1 });
        vm.startPrank(admin);
        uint256 recipeId = proxyV2.addRecipe(ing, SWORD, 1);
        proxyV2.setXPRate(recipeId, 100); // 100 XP per craft
        vm.stopPrank();

        // Give alice resources
        vm.prank(admin); items.mint(alice, WOOD, 5, "");
        vm.prank(alice); items.setApprovalForAll(address(proxyV2), true);

        vm.prank(alice);
        proxyV2.craft(recipeId);

        assertEq(proxyV2.playerXP(alice), 100, "100 XP awarded");
    }

    function test_upgrade_reverts_unauthorized() public {
        CraftingV2 implV2 = new CraftingV2();
        vm.prank(alice); // alice doesn't have UPGRADER_ROLE
        vm.expectRevert();
        proxy.upgradeToAndCall(address(implV2), "");
    }
}
