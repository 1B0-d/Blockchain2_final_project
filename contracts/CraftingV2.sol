// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { CraftingV1 } from "./CraftingV1.sol";

/// @title CraftingV2
/// @notice Upgraded implementation — adds XP reward per crafted item.
///         Deployed as new implementation; proxy state (recipes etc.) is preserved.
///
///         New storage added safely after V1's __gap:
///           xpPerCraft mapping (uint256 recipeId => uint256 xp)
///           playerXP    mapping (address => uint256)
///
///         Demonstrates: CraftingV1 → CraftingV2 upgrade via UUPS.
contract CraftingV2 is CraftingV1 {
    // ───────────────────────── new V2 storage ────────────────────────────────
    /// @dev These slots live AFTER V1's __gap, so no collision.
    mapping(uint256 => uint256) public xpPerCraft;   // recipeId → XP awarded
    mapping(address => uint256) public playerXP;     // player  → total XP

    // ───────────────────────── events ────────────────────────────────────────
    event XPAwarded(address indexed player, uint256 recipeId, uint256 xp);
    event XPRateSet(uint256 indexed recipeId, uint256 xp);

    // ───────────────────────── governance ────────────────────────────────────

    function setXPRate(uint256 recipeId, uint256 xp)
        external onlyRole(RECIPE_MANAGER_ROLE)
    {
        xpPerCraft[recipeId] = xp;
        emit XPRateSet(recipeId, xp);
    }

    // ───────────────────────── craft override ────────────────────────────────

    /// @notice V2 craft: same as V1 but also awards XP.
    function craft(uint256 recipeId) external override nonReentrant {
        // Delegate core logic to parent (burns + mints)
        // NOTE: We call internal logic directly; can't call super.craft() when
        //       overriding because of nonReentrant modifier duplication.
        //       In production, extract _craftCore() as internal in V1.
        //       For demo purposes we inline the V1 logic here.

        if (recipeId >= nextRecipeId) revert RecipeNotFound(recipeId);
        (Ingredient[] memory ingredients, , uint256 outputAmount, bool active) =
            this.getRecipe(recipeId);
        if (!active) revert RecipeInactive(recipeId);

        for (uint256 i; i < ingredients.length; ++i) {
            items.burnFrom(msg.sender, ingredients[i].itemId, ingredients[i].amount);
        }
        (, uint256 outputId, ,) = this.getRecipe(recipeId);
        items.mint(msg.sender, outputId, outputAmount, "");

        emit ItemCrafted(msg.sender, recipeId);

        // Award XP (new V2 feature)
        uint256 xp = xpPerCraft[recipeId];
        if (xp > 0) {
            playerXP[msg.sender] += xp;
            emit XPAwarded(msg.sender, recipeId, xp);
        }
    }

    function version() external pure override returns (string memory) {
        return "V2";
    }
}
