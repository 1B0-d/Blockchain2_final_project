// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console2 } from "forge-std/Script.sol";
import { ERC1967Proxy }       from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { TimelockController }  from "@openzeppelin/contracts/governance/TimelockController.sol";

import { GameToken }    from "../contracts/GameToken.sol";
import { GameItems }    from "../contracts/GameItems.sol";
import { GameVault }    from "../contracts/GameVault.sol";
import { GameTreasury } from "../contracts/GameTreasury.sol";
import { GameGovernor } from "../contracts/GameGovernor.sol";
import { CraftingV1 }   from "../contracts/Crafting.sol";
import { ResourceAMM }  from "../contracts/ResourceAMM.sol";
import { LootDrop }     from "../contracts/LootDrop.sol";
import { RentalVault }  from "../contracts/RentalVault.sol";

contract Deploy is Script {
    // Shared state between deploy steps
    address deployer;
    GameToken    token;
    GameItems    items;
    GameVault    vault;
    TimelockController timelock;
    GameGovernor governor;
    GameTreasury treasury;
    CraftingV1   crafting;
    ResourceAMM  amm;
    LootDrop     lootDrop;
    RentalVault  rental;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.addr(deployerKey);
        console2.log("Deployer:", deployer);

        vm.startBroadcast(deployerKey);
        _deployCore();
        _deployGovernance();
        _deployCrafting();
        _deployAMM();
        _deployLootAndRental();
        vm.stopBroadcast();

        _logSummary();
    }

    function _deployCore() internal {
        token = new GameToken(deployer);
        console2.log("GameToken:   ", address(token));

        items = new GameItems("ipfs://bafybeiplaceholder/", deployer);
        console2.log("GameItems:   ", address(items));

        vault = new GameVault(token, deployer);
        console2.log("GameVault:   ", address(vault));
    }

    function _deployGovernance() internal {
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0);

        timelock = new TimelockController(2 days, proposers, executors, deployer);
        console2.log("Timelock:    ", address(timelock));

        governor = new GameGovernor(token, timelock);
        console2.log("GameGovernor:", address(governor));

        timelock.grantRole(timelock.PROPOSER_ROLE(),  address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);

        treasury = new GameTreasury(address(timelock));
        console2.log("GameTreasury:", address(treasury));
    }

    function _deployCrafting() internal {
        CraftingV1 impl = new CraftingV1();
        bytes memory init = abi.encodeCall(CraftingV1.initialize, (address(items), deployer));
        crafting = CraftingV1(address(new ERC1967Proxy(address(impl), init)));
        console2.log("CraftingV1:  ", address(crafting));

        crafting.grantRole(crafting.RECIPE_MANAGER_ROLE(), address(timelock));
        crafting.grantRole(crafting.UPGRADER_ROLE(),       address(timelock));
        items.grantRole(items.MINTER_ROLE(),      address(crafting));
        items.grantRole(items.GAME_SYSTEM_ROLE(), address(crafting));
    }

    function _deployAMM() internal {
        amm = new ResourceAMM(
            address(items),
            items.WOOD(),
            items.IRON(),
            30,
            deployer,
            deployer
        );
        console2.log("ResourceAMM: ", address(amm));

        amm.grantRole(amm.FEE_MANAGER_ROLE(), address(timelock));
        items.grantRole(items.MINTER_ROLE(),      address(amm));
        items.grantRole(items.GAME_SYSTEM_ROLE(), address(amm));
    }

    function _deployLootAndRental() internal {
        lootDrop = new LootDrop(
            address(items),
            address(0),
            bytes32(0),
            0,
            false,
            0.001 ether,
            deployer,
            deployer
        );
        console2.log("LootDrop:    ", address(lootDrop));

        items.grantRole(items.MINTER_ROLE(),      address(lootDrop));
        items.grantRole(items.GAME_SYSTEM_ROLE(), address(lootDrop));

        rental = new RentalVault(address(items), 7 days, 500, deployer, deployer);
        console2.log("RentalVault: ", address(rental));

        items.grantRole(items.GAME_SYSTEM_ROLE(), address(rental));
    }

    function _logSummary() internal view {
        console2.log("\n=== DEPLOYMENT COMPLETE ===");
        console2.log("GameToken:   ", address(token));
        console2.log("GameItems:   ", address(items));
        console2.log("GameVault:   ", address(vault));
        console2.log("Timelock:    ", address(timelock));
        console2.log("GameGovernor:", address(governor));
        console2.log("GameTreasury:", address(treasury));
        console2.log("CraftingV1:  ", address(crafting));
        console2.log("ResourceAMM: ", address(amm));
        console2.log("LootDrop:    ", address(lootDrop));
        console2.log("RentalVault: ", address(rental));
    }
}
