// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { GameItems } from "../contracts/GameItems.sol";
import { Crafting } from "../contracts/Crafting.sol";

contract CraftingTest is Test {
    GameItems items;
    Crafting  crafting;

    address admin = makeAddr("admin");
    address alice = makeAddr("alice");

    uint256 constant WOOD   = 1;
    uint256 constant IRON   = 2;
    uint256 constant SWORD  = 100;

    function setUp() public {
        vm.startPrank(admin);
        items    = new GameItems("ipfs://test/", admin);
        crafting = new Crafting(address(items), admin);

        // Grant crafting system roles on items
        items.grantRole(items.MINTER_ROLE(),      address(crafting));
        items.grantRole(items.GAME_SYSTEM_ROLE(), address(crafting));
        vm.stopPrank();
    }

    // ── helper ─────────────────────────────────────────────────────────────

    function _addSwordRecipe() internal returns (uint256 recipeId) {
        Crafting.Ingredient[] memory ing = new Crafting.Ingredient[](2);
        ing[0] = Crafting.Ingredient({ itemId: WOOD, amount: 3 });
        ing[1] = Crafting.Ingredient({ itemId: IRON, amount: 2 });

        vm.prank(admin);
        recipeId = crafting.addRecipe(ing, SWORD, 1);
    }

    function _giveAndApprove(address player, uint256 wood, uint256 iron) internal {
        vm.startPrank(admin);
        items.mint(player, WOOD, wood, "");
        items.mint(player, IRON, iron, "");
        vm.stopPrank();

        vm.prank(player);
        items.setApprovalForAll(address(crafting), true);
    }

    // ── addRecipe ─────────────────────────────────────────────────────────

    function test_addRecipe_stores_correctly() public {
        uint256 id = _addSwordRecipe();
        assertEq(id, 0, "first recipe ID is 0");

        (Crafting.Ingredient[] memory ing,, uint256 outAmt, bool active) = crafting.getRecipe(id);
        assertEq(ing.length, 2);
        assertEq(ing[0].itemId, WOOD);
        assertEq(ing[0].amount, 3);
        assertEq(outAmt, 1);
        assertTrue(active);
    }

    function test_addRecipe_increments_nextRecipeId() public {
        _addSwordRecipe();
        _addSwordRecipe(); // second recipe (same output, different id)
        assertEq(crafting.nextRecipeId(), 2);
    }

    function test_addRecipe_reverts_empty_ingredients() public {
        Crafting.Ingredient[] memory ing = new Crafting.Ingredient[](0);
        vm.prank(admin);
        vm.expectRevert(Crafting.InvalidRecipe.selector);
        crafting.addRecipe(ing, SWORD, 1);
    }

    function test_addRecipe_reverts_unauthorized() public {
        Crafting.Ingredient[] memory ing = new Crafting.Ingredient[](1);
        ing[0] = Crafting.Ingredient({ itemId: WOOD, amount: 1 });
        vm.prank(alice);
        vm.expectRevert();
        crafting.addRecipe(ing, SWORD, 1);
    }

    // ── setRecipeActive ───────────────────────────────────────────────────

    function test_setRecipeActive_pauses_recipe() public {
        uint256 id = _addSwordRecipe();
        vm.prank(admin);
        crafting.setRecipeActive(id, false);

        (,,, bool active) = crafting.getRecipe(id);
        assertFalse(active);
    }

    // ── setCraftingCost ───────────────────────────────────────────────────

    function test_setCraftingCost_updates_amount() public {
        uint256 id = _addSwordRecipe();
        vm.prank(admin);
        crafting.setCraftingCost(id, 0, 5); // change WOOD cost from 3 to 5

        (Crafting.Ingredient[] memory ing,,,) = crafting.getRecipe(id);
        assertEq(ing[0].amount, 5);
    }

    function test_setCraftingCost_reverts_zero() public {
        uint256 id = _addSwordRecipe();
        vm.prank(admin);
        vm.expectRevert("Crafting: zero cost");
        crafting.setCraftingCost(id, 0, 0);
    }

    // ── craft ─────────────────────────────────────────────────────────────

    function test_craft_mints_output_and_burns_ingredients() public {
        uint256 id = _addSwordRecipe();
        _giveAndApprove(alice, 10, 10);

        vm.prank(alice);
        crafting.craft(id);

        assertEq(items.balanceOf(alice, WOOD),  7, "3 WOOD burned");
        assertEq(items.balanceOf(alice, IRON),  8, "2 IRON burned");
        assertEq(items.balanceOf(alice, SWORD), 1, "1 SWORD minted");
    }

    function test_craft_reverts_insufficient_ingredients() public {
        uint256 id = _addSwordRecipe();
        // Give only 1 WOOD (need 3)
        vm.prank(admin); items.mint(alice, WOOD, 1, "");
        vm.prank(admin); items.mint(alice, IRON, 10, "");
        vm.prank(alice); items.setApprovalForAll(address(crafting), true);

        vm.prank(alice);
        vm.expectRevert(); // InsufficientIngredients
        crafting.craft(id);
    }

    function test_craft_reverts_inactive_recipe() public {
        uint256 id = _addSwordRecipe();
        vm.prank(admin);
        crafting.setRecipeActive(id, false);

        _giveAndApprove(alice, 10, 10);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Crafting.RecipeInactive.selector, id));
        crafting.craft(id);
    }

    function test_craft_reverts_bad_recipe_id() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Crafting.RecipeNotFound.selector, 99));
        crafting.craft(99);
    }

    // ── fuzz ──────────────────────────────────────────────────────────────

    function testFuzz_craft_multiple_times(uint8 times) public {
        times = uint8(bound(times, 1, 20));
        uint256 id = _addSwordRecipe();
        // Need 3*WOOD + 2*IRON per craft
        _giveAndApprove(alice, uint256(times) * 3, uint256(times) * 2);

        for (uint256 i; i < times; ++i) {
            vm.prank(alice);
            crafting.craft(id);
        }

        assertEq(items.balanceOf(alice, SWORD), times);
        assertEq(items.balanceOf(alice, WOOD),  0);
        assertEq(items.balanceOf(alice, IRON),  0);
    }
}
