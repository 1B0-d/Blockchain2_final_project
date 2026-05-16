// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { GameItems } from "../contracts/GameItems.sol";
import { LootDrop }  from "../contracts/LootDrop.sol";
import { ItemPoolFactory } from "../contracts/ItemPoolFactory.sol";
import { ResourceAMM } from "../contracts/ResourceAMM.sol";
import { ChainlinkPriceOracle } from "../contracts/ChainlinkPriceOracle.sol";
import { YulUtils } from "../contracts/YulUtils.sol";

// ─────────────────────────────────────────────────────────────────────────────
// LootDrop tests (mock VRF mode)
// ─────────────────────────────────────────────────────────────────────────────

contract LootDropTest is Test {
    GameItems items;
    LootDrop  loot;

    address admin   = makeAddr("admin");
    address alice   = makeAddr("alice");
    address feeRcvr = makeAddr("feeReceiver");

    uint256 constant WOOD   = 1;
    uint256 constant IRON   = 2;
    uint256 constant RELIC  = 200;
    uint256 constant FEE    = 0.01 ether;

    function setUp() public {
        vm.startPrank(admin);
        items = new GameItems("ipfs://test/", admin);
        loot  = new LootDrop(
            address(items),
            address(0),  // no VRF coordinator in mock mode
            bytes32(0),
            0,
            false,       // useRealVRF = false
            FEE,
            feeRcvr,
            admin
        );
        items.grantRole(items.MINTER_ROLE(), address(loot));
        vm.stopPrank();

        vm.deal(alice, 1 ether);
    }

    function _setDropTable() internal {
        LootDrop.LootEntry[] memory entries = new LootDrop.LootEntry[](3);
        entries[0] = LootDrop.LootEntry({ itemId: WOOD,  weight: 70 });
        entries[1] = LootDrop.LootEntry({ itemId: IRON,  weight: 25 });
        entries[2] = LootDrop.LootEntry({ itemId: RELIC, weight: 5  });
        vm.prank(admin);
        loot.setDropTable(entries);
    }

    function test_openLootBox_mints_item() public {
        _setDropTable();
        vm.prank(alice);
        loot.openLootBox{ value: FEE }();

        // Alice should have received exactly 1 of some item
        uint256 total = items.balanceOf(alice, WOOD)
                      + items.balanceOf(alice, IRON)
                      + items.balanceOf(alice, RELIC);
        assertEq(total, 1, "exactly one item minted");
    }

    function test_openLootBox_sends_fee() public {
        _setDropTable();
        uint256 before = feeRcvr.balance;
        vm.prank(alice);
        loot.openLootBox{ value: FEE }();
        assertEq(feeRcvr.balance, before + FEE);
    }

    function test_openLootBox_refunds_excess() public {
        _setDropTable();
        uint256 before = alice.balance;
        vm.prank(alice);
        loot.openLootBox{ value: FEE + 0.5 ether }();
        assertEq(alice.balance, before - FEE, "excess refunded");
    }

    function test_openLootBox_reverts_empty_table() public {
        vm.prank(alice);
        vm.expectRevert(LootDrop.DropTableEmpty.selector);
        loot.openLootBox{ value: FEE }();
    }

    function test_openLootBox_reverts_insufficient_fee() public {
        _setDropTable();
        vm.prank(alice);
        vm.expectRevert(); // InsufficientFee
        loot.openLootBox{ value: FEE - 1 }();
    }

    function test_setDropTable_updates_totalWeight() public {
        _setDropTable();
        assertEq(loot.totalWeight(), 100);
    }

    function test_setLootFee_governance() public {
        vm.prank(admin);
        loot.setLootFee(0.05 ether);
        assertEq(loot.lootFee(), 0.05 ether);
    }

    function testFuzz_openLootBox_distribution(uint8 rolls) public {
        rolls = uint8(bound(rolls, 1, 50));
        _setDropTable();

        vm.deal(alice, uint256(rolls) * FEE + 1 ether);

        for (uint256 i; i < rolls; ++i) {
            vm.roll(block.number + i + 1);
            vm.warp(block.timestamp + i + 1);
            vm.prank(alice);
            loot.openLootBox{ value: FEE }();
        }

        uint256 total = items.balanceOf(alice, WOOD)
                      + items.balanceOf(alice, IRON)
                      + items.balanceOf(alice, RELIC);
        assertEq(total, rolls, "each roll mints exactly 1 item");
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// ItemPoolFactory tests (CREATE + CREATE2)
// ─────────────────────────────────────────────────────────────────────────────

contract ItemPoolFactoryTest is Test {
    GameItems       items;
    ItemPoolFactory factory;

    address admin   = makeAddr("admin");
    address feeRcvr = makeAddr("feeReceiver");

    uint256 constant A = 1;
    uint256 constant B = 2;
    uint256 constant C = 3;

    function setUp() public {
        vm.startPrank(admin);
        items   = new GameItems("ipfs://", admin);
        factory = new ItemPoolFactory(admin);
        vm.stopPrank();
    }

    function test_deployPool_CREATE() public {
        vm.prank(admin);
        address pool = factory.deployPool(address(items), A, B, 30, feeRcvr);
        assertNotEq(pool, address(0));
        assertEq(factory.allPoolsLength(), 1);
        assertEq(factory.getPool(A, B), pool);
        assertEq(factory.getPool(B, A), pool); // bidirectional
    }

    function test_deployPool_CREATE2() public {
        bytes32 salt = keccak256("pool-A-B");
        vm.prank(admin);
        address pool = factory.deployPool2(address(items), A, B, 30, feeRcvr, salt);
        assertNotEq(pool, address(0));
        assertEq(factory.allPoolsLength(), 1);
    }

    function test_deployPool2_address_is_deterministic() public {
        bytes32 salt = keccak256("my-salt");

        address predicted = factory.predictAddress(address(items), A, B, 30, feeRcvr, salt);

        vm.prank(admin);
        address actual = factory.deployPool2(address(items), A, B, 30, feeRcvr, salt);

        assertEq(actual, predicted, "CREATE2 address must match prediction");
    }

    function test_deployPool_reverts_duplicate_pair() public {
        vm.startPrank(admin);
        factory.deployPool(address(items), A, B, 30, feeRcvr);
        vm.expectRevert(abi.encodeWithSelector(ItemPoolFactory.PoolAlreadyExists.selector, A, B));
        factory.deployPool(address(items), A, B, 30, feeRcvr);
        vm.stopPrank();
    }

    function test_deployPool_sorts_tokens() public {
        // Deploying B->A should register same as A->B
        vm.prank(admin);
        address pool = factory.deployPool(address(items), B, A, 30, feeRcvr);
        assertEq(factory.getPool(A, B), pool);
    }

    function test_multiple_pairs() public {
        vm.startPrank(admin);
        factory.deployPool(address(items), A, B, 30, feeRcvr);
        factory.deployPool(address(items), B, C, 30, feeRcvr);
        vm.stopPrank();
        assertEq(factory.allPoolsLength(), 2);
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// ChainlinkPriceOracle tests (mock feed)
// ─────────────────────────────────────────────────────────────────────────────

/// @dev Mock Chainlink aggregator
contract MockAggregator {
    int256  public price;
    uint256 public updatedAt;
    uint80  public roundId;
    uint80  public answeredInRound;
    uint8   public dec = 8;

    function set(int256 _price, uint256 _updatedAt, uint80 _roundId, uint80 _answeredInRound) external {
        price           = _price;
        updatedAt       = _updatedAt;
        roundId         = _roundId;
        answeredInRound = _answeredInRound;
    }

    function decimals() external view returns (uint8) { return dec; }

    function latestRoundData() external view returns (
        uint80, int256, uint256, uint256, uint80
    ) {
        return (roundId, price, 0, updatedAt, answeredInRound);
    }
}

contract ChainlinkOracleTest is Test {
    MockAggregator       feed;
    ChainlinkPriceOracle oracle;

    address admin = makeAddr("admin");

    uint256 constant MAX_STALENESS = 3600; // 1 hour

    function setUp() public {
        feed   = new MockAggregator();
        oracle = new ChainlinkPriceOracle(address(feed), MAX_STALENESS, admin);

        // Valid fresh price
        feed.set(2000e8, block.timestamp, 1, 1);
    }

    function test_getLatestPrice_returns_valid() public view {
        (int256 price,) = oracle.getLatestPrice();
        assertEq(price, 2000e8);
    }

    function test_getLatestPrice_reverts_stale() public {
        feed.set(2000e8, block.timestamp - MAX_STALENESS - 1, 1, 1);
        vm.expectRevert(); // StalePrice
        oracle.getLatestPrice();
    }

    function test_getLatestPrice_reverts_zero_price() public {
        feed.set(0, block.timestamp, 1, 1);
        vm.expectRevert(); // InvalidPrice
        oracle.getLatestPrice();
    }

    function test_getLatestPrice_reverts_negative_price() public {
        feed.set(-1, block.timestamp, 1, 1);
        vm.expectRevert();
        oracle.getLatestPrice();
    }

    function test_getLatestPrice_reverts_incomplete_round() public {
        feed.set(2000e8, block.timestamp, 5, 4); // answeredInRound < roundId
        vm.expectRevert();
        oracle.getLatestPrice();
    }

    function test_getLatestPriceScaled_to_18_decimals() public view {
        uint256 scaled = oracle.getLatestPriceScaled();
        // 2000e8 scaled from 8 decimals to 18 decimals = 2000e18
        assertEq(scaled, 2000e18);
    }

    function test_setMaxStaleness_governance() public {
        vm.prank(admin);
        oracle.setMaxStaleness(7200);
        assertEq(oracle.maxStaleness(), 7200);
    }

    function test_setMaxStaleness_reverts_unauthorized() public {
        vm.expectRevert();
        oracle.setMaxStaleness(7200);
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// YulUtils tests — Yul vs Solidity equivalence
// ─────────────────────────────────────────────────────────────────────────────

/// @dev Wrapper contract to expose library functions for testing
contract YulUtilsWrapper {
    function sqrtYul(uint256 y) external pure returns (uint256) { return YulUtils.sqrtYul(y); }
    function sqrtSol(uint256 y) external pure returns (uint256) { return YulUtils.sqrtSol(y); }

    function packYul(address a, uint96 v) external pure returns (bytes32) {
        return YulUtils.packAddressAmountYul(a, v);
    }
    function packSol(address a, uint96 v) external pure returns (bytes32) {
        return YulUtils.packAddressAmountSol(a, v);
    }
    function unpackYul(bytes32 p) external pure returns (address, uint96) {
        return YulUtils.unpackAddressAmountYul(p);
    }
    function unpackSol(bytes32 p) external pure returns (address, uint96) {
        return YulUtils.unpackAddressAmountSol(p);
    }
    function minYul(uint256 a, uint256 b) external pure returns (uint256) { return YulUtils.minYul(a, b); }
    function minSol(uint256 a, uint256 b) external pure returns (uint256) { return YulUtils.minSol(a, b); }
    function outYul(uint256 i, uint256 rI, uint256 rO) external pure returns (uint256) {
        return YulUtils.getAmountOutYul(i, rI, rO);
    }
    function outSol(uint256 i, uint256 rI, uint256 rO) external pure returns (uint256) {
        return YulUtils.getAmountOutSol(i, rI, rO);
    }
}

contract YulUtilsTest is Test {
    YulUtilsWrapper w;

    function setUp() public {
        w = new YulUtilsWrapper();
    }

    // ── sqrt equivalence ─────────────────────────────────────────────────────

    function test_sqrt_known_values() public view {
        assertEq(w.sqrtYul(0),   0);
        assertEq(w.sqrtYul(1),   1);
        assertEq(w.sqrtYul(4),   2);
        assertEq(w.sqrtYul(9),   3);
        assertEq(w.sqrtYul(100), 10);
    }

    function testFuzz_sqrt_yul_eq_sol(uint256 y) public view {
        y = bound(y, 0, type(uint128).max); // avoid overflow in sqrt
        assertEq(w.sqrtYul(y), w.sqrtSol(y), "sqrt Yul != Sol");
    }

    // ── pack equivalence ─────────────────────────────────────────────────────

    function testFuzz_pack_yul_eq_sol(address addr, uint96 amount) public view {
        assertEq(w.packYul(addr, amount), w.packSol(addr, amount));
    }

    function testFuzz_unpack_roundtrip(address addr, uint96 amount) public view {
        bytes32 packed = w.packYul(addr, amount);
        (address a1, uint96 v1) = w.unpackYul(packed);
        (address a2, uint96 v2) = w.unpackSol(packed);
        assertEq(a1, addr);
        assertEq(v1, amount);
        assertEq(a1, a2);
        assertEq(v1, v2);
    }

    // ── min equivalence ───────────────────────────────────────────────────────

    function testFuzz_min_yul_eq_sol(uint256 a, uint256 b) public view {
        assertEq(w.minYul(a, b), w.minSol(a, b));
    }

    // ── AMM output equivalence ────────────────────────────────────────────────

    function testFuzz_amountOut_yul_eq_sol(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public view {
        // Bound to avoid overflow in mul(reserveIn, reserveOut)
        reserveIn  = bound(reserveIn,  1, 1e18);
        reserveOut = bound(reserveOut, 1, 1e18);
        amountIn   = bound(amountIn,   1, reserveIn); // keep sane
        // Also ensure reserveIn*reserveOut won't overflow uint256
        vm.assume(reserveIn < type(uint128).max && reserveOut < type(uint128).max);

        uint256 yul = w.outYul(amountIn, reserveIn, reserveOut);
        uint256 sol = w.outSol(amountIn, reserveIn, reserveOut);
        assertEq(yul, sol, "AMM out Yul != Sol");
    }
}
