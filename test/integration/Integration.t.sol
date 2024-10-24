// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {ConnectorPlugin} from "../../src/ConnectorPlugin.sol";
import {ConnectorRegistry} from "../../src/ConnectorPlugin.sol";

import "../../src/connectors/base/aerodrome/main.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IRouter} from "@aerodrome/contracts/contracts/interfaces/IRouter.sol";
import {IPoolFactory} from "@aerodrome/contracts/contracts/interfaces/factories/IPoolFactory.sol";

contract Integration is Test {

    ConnectorPlugin public plugin;
    ConnectorRegistry public registry;
    AerodromeConnector public connector;
    address public constant ALICE = address(0x1);

    address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public constant AERODROME_ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address public constant AERODROME_FACTORY = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    address public constant AERO = 0x940181a94A35A4569E4529A3CDfB74e38FD98631;
    // You'll need to replace these with actual addresses from the Aerodrome deployment
    address public constant USDC_WETH_POOL = 0xcDAC0d6c6C59727a65F871236188350531885C43;
    address public constant USDC_WETH_GAUGE = 0x519BBD1Dd8C6A94C46080E24f316c14Ee758C025;

    uint256 public constant INITIAL_BALANCE = 1_000_000 * 1e6; // 1 million USDC
    uint256 public constant INITIAL_ETH_BALANCE = 1000 ether;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
        registry = new ConnectorRegistry();

        plugin = new ConnectorPlugin(address(registry));
        connector = new AerodromeConnector("AerodromeConnector", 1, address(plugin));
        registry.addConnector(address(connector), "AerodromeConnector", 1);

        deal(ALICE, INITIAL_ETH_BALANCE);
        deal(USDC, ALICE, INITIAL_BALANCE);
        deal(WETH, ALICE, INITIAL_ETH_BALANCE);


        vm.startPrank(ALICE);
        IERC20(USDC).approve(address(connector), type(uint256).max);
        IERC20(WETH).approve(address(connector), type(uint256).max);
        IERC20(USDC_WETH_POOL).approve(address(connector), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(address(connector));
        IERC20(WETH).approve(AERODROME_ROUTER, type(uint256).max);
        IERC20(USDC).approve(AERODROME_ROUTER, type(uint256).max);
        vm.stopPrank();
    }


    function test_plugin_addLiquidity() public {
        uint256 amountADesired = 1000 * 1e6; // 1,000 USDC
        uint256 amountBDesired = 1 ether; // 1 WETH
        bool stable = false;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 slippage = 60; // 0.6%

        vm.startPrank(ALICE);


        bytes memory data = abi.encodeWithSelector(
            IRouter.addLiquidity.selector,
            USDC,
            WETH,
            stable,
            amountADesired,
            amountBDesired,
            slippage,
            ALICE,
            deadline
        );

        address pool = IPoolFactory(AERODROME_FACTORY).getPool(USDC, WETH, stable);

        console.log("Liquidity balance of Alice before deposit: %e", IERC20(pool).balanceOf(ALICE));

        bytes memory result = plugin.execute(address(connector), data);
        (uint256 amountA, uint256 amountB, uint256 liquidity) = abi.decode(result, (uint256, uint256, uint256));

        console.log("Liquidity added: %e USDC, %e WETH", amountA, amountB);

        assertGt(amountA, 0, "Amount A should be greater than 0");
        assertGt(amountB, 0, "Amount B should be greater than 0");
        assertGt(liquidity, 0, "Liquidity should be greater than 0");

        // console.log("USDC balance after: %s", IERC20(USDC).balanceOf(ALICE));
        // console.log("WETH balance after: %s", IERC20(WETH).balanceOf(ALICE));
        console.log("Liquidity balance of Alice after deposit: %e", IERC20(pool).balanceOf(ALICE));

        vm.stopPrank();
    }

    function test_plugin_addLiquidityETH() public {
        uint256 amountADesired = 1000 * 1e6; // 1,000 USDC
        uint256 amountBDesired = 1 ether; // 1 WETH
        bool stable = false;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 slippage = 60; // 0.6%

        vm.startPrank(ALICE);

        bytes memory data = abi.encodeWithSelector(
            IRouter.addLiquidity.selector,
            USDC,
            WETH,
            stable,
            amountADesired,
            amountBDesired,
            slippage,
            ALICE,
            deadline
        );

        address pool = IPoolFactory(AERODROME_FACTORY).getPool(USDC, WETH, stable);

        console.log("Liquidity balance of Alice before deposit: %e", IERC20(pool).balanceOf(ALICE));

        bytes memory result = plugin.execute{value: amountBDesired}(address(connector), data);
        (uint256 amountA, uint256 amountB, uint256 liquidity) = abi.decode(result, (uint256, uint256, uint256));

        console.log("Liquidity added: %e USDC, %e WETH", amountA, amountB);

        assertGt(amountA, 0, "Amount A should be greater than 0");
        assertGt(amountB, 0, "Amount B should be greater than 0");
        assertGt(liquidity, 0, "Liquidity should be greater than 0");

        // console.log("USDC balance after: %s", IERC20(USDC).balanceOf(ALICE));
        // console.log("WETH balance after: %s", IERC20(WETH).balanceOf(ALICE));
        console.log("Liquidity balance of Alice after deposit: %e", IERC20(pool).balanceOf(ALICE));

        vm.stopPrank();
    }

    function test_plugin_removeLiquidity() public {
        // First, add liquidity
        test_plugin_addLiquidity();

        // Now remove liquidity
        address pair = IPoolFactory(AERODROME_FACTORY).getPool(USDC, WETH, false);
        require(pair != address(0), "Pair does not exist");

        uint256 liquidity = IERC20(pair).balanceOf(ALICE);
        require(liquidity > 0, "No liquidity to remove");

        uint256 amountAMin = 1;
        uint256 amountBMin = 1;
        bool stable = false;
        uint256 deadline = block.timestamp + 1 hours;

        vm.startPrank(ALICE);

        console.log("LP token balance before: %s", liquidity);
        console.log("USDC balance before: %s", IERC20(USDC).balanceOf(ALICE));
        console.log("WETH balance before: %s", IERC20(WETH).balanceOf(ALICE));

        IERC20(pair).approve(address(connector), liquidity);

        bytes memory data = abi.encodeWithSelector(
            IRouter.removeLiquidity.selector, USDC, WETH, stable, liquidity, amountAMin, amountBMin, ALICE, deadline
        );

        plugin.execute(address(connector), data);

        console.log("LP token balance after: %s", IERC20(pair).balanceOf(ALICE));
        console.log("USDC balance after: %s", IERC20(USDC).balanceOf(ALICE));
        console.log("WETH balance after: %s", IERC20(WETH).balanceOf(ALICE));

        vm.stopPrank();
    }

    function test_plugin_SwapExactTokensForTokens() public {
        uint256 amountIn = 1000 * 1e6; // 1,000 USDC
        uint256 amountOutMin = 0.1 ether; // Minimum 0.1 WETH expected
        uint256 deadline = block.timestamp + 1 hours;

        vm.startPrank(ALICE);

        console.log("USDC balance before: %s", IERC20(USDC).balanceOf(ALICE));
        console.log("WETH balance before: %s", IERC20(WETH).balanceOf(ALICE));

        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route({from: USDC, to: WETH, stable: false, factory: AERODROME_FACTORY});

        // Calculate expected output
        uint256[] memory expectedAmounts = IRouter(AERODROME_ROUTER).getAmountsOut(amountIn, routes);
        uint256 expectedAmountOut = expectedAmounts[expectedAmounts.length - 1];

        // Set minReturnAmount to 99% of expected output (1% slippage tolerance)
        uint256 minReturnAmount = (expectedAmountOut * 99) / 100;

        bytes memory data = abi.encodeWithSelector(
            IRouter.swapExactTokensForTokens.selector, amountIn, minReturnAmount, routes, ALICE, deadline
        );

        bytes memory result = plugin.execute(address(connector), data);

        console.logBytes(result);
        uint256[] memory amounts = abi.decode(result, (uint256[]));

        console.log("Swapped: %s USDC for %s WETH", amounts[0], amounts[amounts.length - 1]);

        assertEq(amounts[0], amountIn, "Input amount should match");
        assertGt(amounts[amounts.length - 1], amountOutMin, "Output amount should be greater than minimum");
        assertGe(
            amounts[amounts.length - 1], minReturnAmount, "Output amount should be greater than or equal to minimum"
        );

        console.log("USDC balance after: %s", IERC20(USDC).balanceOf(ALICE));
        console.log("WETH balance after: %s", IERC20(WETH).balanceOf(ALICE));

        vm.stopPrank();
    }

    function test_plugin_SwapExactTokensForTokens_ETH() public {
        uint256 amountIn = INITIAL_ETH_BALANCE;
        uint256 amountOutMin = 0;
        uint256 deadline = block.timestamp + 1 hours;

        vm.startPrank(ALICE);


        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route({from: WETH, to: USDC, stable: false, factory: AERODROME_FACTORY});

        // Calculate expected output
        uint256[] memory expectedAmounts = IRouter(AERODROME_ROUTER).getAmountsOut(amountIn, routes);
        uint256 expectedAmountOut = expectedAmounts[expectedAmounts.length - 1];

        // Set minReturnAmount to 99% of expected output (1% slippage tolerance)
        uint256 minReturnAmount = (expectedAmountOut * 99) / 100;

        bytes memory data = abi.encodeWithSelector(
            IRouter.swapExactTokensForTokens.selector, amountIn, minReturnAmount, routes, ALICE, deadline
        );

        bytes memory result = plugin.execute{value: amountIn}(address(connector), data);

        console.logBytes(result);
        uint256[] memory amounts = abi.decode(result, (uint256[]));

        console.log("Swapped: %e WETH for %e USDC", amounts[0], amounts[amounts.length - 1]);

        assertEq(amounts[0], amountIn, "Input amount should match");
        assertGt(amounts[amounts.length - 1], amountOutMin, "Output amount should be greater than minimum");
        assertGe(
            amounts[amounts.length - 1], minReturnAmount, "Output amount should be greater than or equal to minimum"
        );

        vm.stopPrank();
    }

    function test_plugin_depositToGauge() public {
        // First, add liquidity to get LP tokens
        test_plugin_addLiquidity();

        uint256 lpBalance = IERC20(USDC_WETH_POOL).balanceOf(ALICE);
        require(lpBalance > 0, "No LP tokens to deposit");

        uint256 depositAmount = lpBalance / 2; // Deposit half of the LP tokens

        vm.startPrank(ALICE);

        // Approve the AerodromeConnector to spend LP tokens
        IERC20(USDC_WETH_POOL).approve(address(connector), depositAmount);

        bytes memory data = abi.encodeWithSelector(IGauge.deposit.selector, USDC_WETH_GAUGE, depositAmount);

        plugin.execute(address(connector), data);

        assertEq(IGauge(USDC_WETH_GAUGE).balanceOf(ALICE), depositAmount, "Gauge balance should match deposit amount");
        assertEq(IERC20(USDC_WETH_POOL).balanceOf(ALICE), lpBalance - depositAmount, "LP token balance should decrease");

        vm.stopPrank();
    }
}
