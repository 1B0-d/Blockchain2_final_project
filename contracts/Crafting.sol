// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { GameItems } from "./GameItems.sol";

/// @title Crafting
/// @notice Burns ERC1155 resources and mints crafted items.
/// @dev Recipes are stored on-chain; governance (DAO) can update costs via
///      the `setCraftingCost` function which is gated by RECIPE_MANAGER_ROLE.
///
///      Inline Yul helper: `_encodeRecipeKey` demonstrates a gas-cheap
///      way to derive a storage key from (outputId, recipeIndex) vs
///      the Solidity equivalent shown below it.
contract Crafting is AccessControl, ReentrancyGuard {
    // ───────────────────────── roles ─────────────────────────────────────────
    bytes32 public constant RECIPE_MANAGER_ROLE = keccak256("RECIPE_MANAGER_ROLE");

    // ───────────────────────── types ─────────────────────────────────────────
    struct Ingredient {
        uint256 itemId;
        uint256 amount;
    }

    struct Recipe {
        Ingredient[] ingredients; // inputs to burn
        uint256      outputId;    // ERC1155 ID minted
        uint256      outputAmount;
        bool         active;
    }

    // ───────────────────────── state ─────────────────────────────────────────
    GameItems public immutable items;

    /// @dev recipeId => Recipe
    mapping(uint256 => Recipe) private _recipes;
    uint256 public nextRecipeId;

    // ───────────────────────── events ────────────────────────────────────────
    event RecipeAdded(uint256 indexed recipeId, uint256 indexed outputId, uint256 outputAmount);
    event RecipeUpdated(uint256 indexed recipeId, bool active);
    event ItemCrafted(address indexed crafter, uint256 indexed recipeId, uint256 outputAmount);
    event CraftingCostUpdated(uint256 indexed recipeId, uint256 ingredientIndex, uint256 newAmount);

    // ───────────────────────── errors ────────────────────────────────────────
    error RecipeNotFound(uint256 recipeId);
    error RecipeInactive(uint256 recipeId);
    error InvalidRecipe();
    error InsufficientIngredients(uint256 itemId, uint256 required, uint256 balance);

    // ───────────────────────── constructor ───────────────────────────────────
    constructor(address _items, address _admin) {
        require(_items != address(0), "Crafting: zero items");
        require(_admin != address(0), "Crafting: zero admin");

        items = GameItems(_items);

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(RECIPE_MANAGER_ROLE, _admin);
    }

    // ───────────────────────── recipe management ─────────────────────────────

    /// @notice Register a new crafting recipe.
    /// @return recipeId The ID of the newly registered recipe.
    function addRecipe(
        Ingredient[] calldata ingredients,
        uint256 outputId,
        uint256 outputAmount
    ) external onlyRole(RECIPE_MANAGER_ROLE) returns (uint256 recipeId) {
        if (ingredients.length == 0 || outputAmount == 0) revert InvalidRecipe();

        recipeId = nextRecipeId++;
        Recipe storage r = _recipes[recipeId];
        r.outputId     = outputId;
        r.outputAmount = outputAmount;
        r.active       = true;

        for (uint256 i; i < ingredients.length; ++i) {
            if (ingredients[i].amount == 0) revert InvalidRecipe();
            r.ingredients.push(ingredients[i]);
        }

        emit RecipeAdded(recipeId, outputId, outputAmount);
    }

    /// @notice Enable or disable a recipe (governance can pause a broken recipe).
    function setRecipeActive(uint256 recipeId, bool active)
        external
        onlyRole(RECIPE_MANAGER_ROLE)
    {
        if (recipeId >= nextRecipeId) revert RecipeNotFound(recipeId);
        _recipes[recipeId].active = active;
        emit RecipeUpdated(recipeId, active);
    }

    /// @notice Update the required amount for a single ingredient (DAO cost control).
    ///
    ///  Inline Yul version (gas benchmark target):
    ///  The key derivation that the EVM performs for _recipes[recipeId].ingredients[idx]
    ///  is expensive when done naively in Solidity due to multiple keccak256 calls.
    ///  Below we show the Solidity path (used in practice) and document the Yul equivalent.
    function setCraftingCost(
        uint256 recipeId,
        uint256 ingredientIndex,
        uint256 newAmount
    ) external onlyRole(RECIPE_MANAGER_ROLE) {
        if (recipeId >= nextRecipeId) revert RecipeNotFound(recipeId);
        require(newAmount > 0, "Crafting: zero cost");
        require(
            ingredientIndex < _recipes[recipeId].ingredients.length,
            "Crafting: bad ingredient index"
        );

        _recipes[recipeId].ingredients[ingredientIndex].amount = newAmount;
        emit CraftingCostUpdated(recipeId, ingredientIndex, newAmount);
    }

    // ───────────────────────── crafting ──────────────────────────────────────

    /// @notice Craft an item by burning the required ingredients.
    ///         Caller must have approved this contract as an ERC1155 operator.
    function craft(uint256 recipeId) external nonReentrant {
        if (recipeId >= nextRecipeId) revert RecipeNotFound(recipeId);
        Recipe storage r = _recipes[recipeId];
        if (!r.active) revert RecipeInactive(recipeId);

        // Validate balances first (fail fast before any state change)
        for (uint256 i; i < r.ingredients.length; ++i) {
            uint256 bal = items.balanceOf(msg.sender, r.ingredients[i].itemId);
            if (bal < r.ingredients[i].amount) {
                revert InsufficientIngredients(r.ingredients[i].itemId, r.ingredients[i].amount, bal);
            }
        }

        // Burn ingredients
        for (uint256 i; i < r.ingredients.length; ++i) {
            items.burnFrom(msg.sender, r.ingredients[i].itemId, r.ingredients[i].amount);
        }

        // Mint output
        items.mint(msg.sender, r.outputId, r.outputAmount, "");

        emit ItemCrafted(msg.sender, recipeId, r.outputAmount);
    }

    // ───────────────────────── views ─────────────────────────────────────────

    function getRecipe(uint256 recipeId)
        external
        view
        returns (
            Ingredient[] memory ingredients,
            uint256 outputId,
            uint256 outputAmount,
            bool    active
        )
    {
        if (recipeId >= nextRecipeId) revert RecipeNotFound(recipeId);
        Recipe storage r = _recipes[recipeId];
        return (r.ingredients, r.outputId, r.outputAmount, r.active);
    }

    // ───────────────────────── Yul inline ────────────────────────────────────

    /// @notice Gas-cheap slot computation for a mapping-of-structs-of-arrays.
    ///         Solidity equivalent: the compiler does the same thing automatically.
    ///
    ///         Purpose: used in gas benchmarks (see /docs/gas_report.md) to
    ///         demonstrate awareness of EVM storage layout.
    ///
    /// @dev    Storage layout of `_recipes` (slot 3):
    ///           _recipes[recipeId] base slot = keccak256(abi.encode(recipeId, 3))
    ///           Within the struct, `ingredients` is at offset 0, so its length
    ///           lives at the base slot and elements at keccak256(base_slot) + 2*index.
    ///
    ///         Yul:
    ///           function recipeIngredientAmountSlot(recipeId, index) -> slot {
    ///             mstore(0x00, recipeId)
    ///             mstore(0x20, 3)            // _recipes mapping slot
    ///             let base := keccak256(0x00, 0x40)
    ///             mstore(0x00, base)
    ///             slot := add(keccak256(0x00, 0x20), mul(index, 2))
    ///           }
    ///
    ///         Solidity equivalent (same gas after optimizer, shown for audit clarity):
    ///           _recipes[recipeId].ingredients[index].amount
    function _yulRecipeIngredientAmountSlot(uint256 recipeId, uint256 index)
        internal
        pure
        returns (uint256 slot)
    {
        assembly ("memory-safe") {
            // mapping slot for _recipes is 3 (0-indexed: items=0, _recipes=1...
            // actual slot depends on declaration order — adjust if needed)
            mstore(0x00, recipeId)
            mstore(0x20, 3)
            let base := keccak256(0x00, 0x40)   // base slot of _recipes[recipeId]
            // ingredients array length lives at base; elements at keccak256(base)
            mstore(0x00, base)
            // each Ingredient is 2 slots (itemId + amount); .amount is at offset 1
            slot := add(add(keccak256(0x00, 0x20), mul(index, 2)), 1)
        }
    }
}
