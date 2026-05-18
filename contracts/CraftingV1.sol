// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// NOTE: requires @openzeppelin/contracts-upgradeable
// Run: npm install @openzeppelin/contracts-upgradeable
// And add remapping: @openzeppelin/contracts-upgradeable/=node_modules/@openzeppelin/contracts-upgradeable/

import { AccessControlUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { UUPSUpgradeable } from
    "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from
    "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { GameItems } from "./GameItems.sol";

/// @title CraftingV1
/// @notice UUPS-upgradeable version of the Crafting contract (V1).
///         Deploy behind an ERC1967Proxy; upgrade to CraftingV2 via DAO proposal.
///
///         Demonstrates mandatory requirement: UUPS upgrade pattern.
///
/// @dev    Storage layout must remain compatible across upgrades.
///         V1 storage (do NOT reorder in V2):
///           slot 0: items (GameItems)
///           slot 1: nextRecipeId (uint256)
///           slot 2: _recipes (mapping)
///           [gap: __gap[47] reserved for future fields]
contract CraftingV1 is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    // ───────────────────────── roles ─────────────────────────────────────────
    bytes32 public constant RECIPE_MANAGER_ROLE = keccak256("RECIPE_MANAGER_ROLE");
    bytes32 public constant UPGRADER_ROLE       = keccak256("UPGRADER_ROLE");

    // ───────────────────────── types ─────────────────────────────────────────
    struct Ingredient {
        uint256 itemId;
        uint256 amount;
    }

    struct Recipe {
        Ingredient[] ingredients;
        uint256      outputId;
        uint256      outputAmount;
        bool         active;
    }

    // ───────────────────────── storage (V1) ──────────────────────────────────
    GameItems public items;
    uint256   public nextRecipeId;
    mapping(uint256 => Recipe) private _recipes;

    /// @dev Storage gap for future V2+ fields.
    uint256[47] private __gap;

    // ───────────────────────── events ────────────────────────────────────────
    event RecipeAdded(uint256 indexed recipeId, uint256 indexed outputId);
    event RecipeToggled(uint256 indexed recipeId, bool active);
    event ItemCrafted(address indexed crafter, uint256 indexed recipeId);
    event CraftingCostUpdated(uint256 indexed recipeId, uint256 ingredientIndex, uint256 newAmount);

    // ───────────────────────── errors ────────────────────────────────────────
    error RecipeNotFound(uint256 recipeId);
    error RecipeInactive(uint256 recipeId);
    error InvalidRecipe();

    // ───────────────────────── initializer ───────────────────────────────────

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _items, address _admin) external initializer {
        require(_items != address(0), "CraftingV1: zero items");
        require(_admin != address(0), "CraftingV1: zero admin");

        __AccessControl_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        items = GameItems(_items);

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(RECIPE_MANAGER_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _admin);
    }

    // ───────────────────────── recipe management ─────────────────────────────

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

        emit RecipeAdded(recipeId, outputId);
    }

    function setRecipeActive(uint256 recipeId, bool active)
        external onlyRole(RECIPE_MANAGER_ROLE)
    {
        if (recipeId >= nextRecipeId) revert RecipeNotFound(recipeId);
        _recipes[recipeId].active = active;
        emit RecipeToggled(recipeId, active);
    }

    /// @notice Update ingredient cost — callable by governance (DAO timelock).
    function setCraftingCost(uint256 recipeId, uint256 ingredientIndex, uint256 newAmount)
        external onlyRole(RECIPE_MANAGER_ROLE)
    {
        if (recipeId >= nextRecipeId) revert RecipeNotFound(recipeId);
        require(newAmount > 0, "CraftingV1: zero cost");
        require(ingredientIndex < _recipes[recipeId].ingredients.length, "CraftingV1: bad index");
        _recipes[recipeId].ingredients[ingredientIndex].amount = newAmount;
        emit CraftingCostUpdated(recipeId, ingredientIndex, newAmount);
    }

    // ───────────────────────── crafting ──────────────────────────────────────

    function craft(uint256 recipeId) external virtual nonReentrant {
        if (recipeId >= nextRecipeId) revert RecipeNotFound(recipeId);
        Recipe storage r = _recipes[recipeId];
        if (!r.active) revert RecipeInactive(recipeId);

        for (uint256 i; i < r.ingredients.length; ++i) {
            items.burnFrom(msg.sender, r.ingredients[i].itemId, r.ingredients[i].amount);
        }
        items.mint(msg.sender, r.outputId, r.outputAmount, "");
        emit ItemCrafted(msg.sender, recipeId);
    }

    // ───────────────────────── views ─────────────────────────────────────────

    function getRecipe(uint256 recipeId)
        external view
        returns (Ingredient[] memory ingredients, uint256 outputId, uint256 outputAmount, bool active)
    {
        if (recipeId >= nextRecipeId) revert RecipeNotFound(recipeId);
        Recipe storage r = _recipes[recipeId];
        return (r.ingredients, r.outputId, r.outputAmount, r.active);
    }

    /// @notice Returns the implementation version — overridden in V2.
    function version() external pure virtual returns (string memory) {
        return "V1";
    }

    // ───────────────────────── UUPS ──────────────────────────────────────────

    /// @dev Only accounts with UPGRADER_ROLE (i.e. the DAO timelock) can upgrade.
    function _authorizeUpgrade(address newImplementation)
        internal override onlyRole(UPGRADER_ROLE)
    {}
}
