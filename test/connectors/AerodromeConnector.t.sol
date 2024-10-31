// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../src/connectors/base/aerodrome/main.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IRouter} from "@aerodrome/contracts/contracts/interfaces/IRouter.sol";
import {IPoolFactory} from "@aerodrome/contracts/contracts/interfaces/factories/IPoolFactory.sol";
import {IPool} from "@aerodrome/contracts/contracts/interfaces/IPool.sol";

contract AerodromeConnectorTest is Test {
    AerodromeConnector public connector;
    address public ALICE = makeAddr("alice");

    address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public constant AERODROME_ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address public constant AERODROME_FACTORY = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    address public constant AERO = 0x940181a94A35A4569E4529A3CDfB74e38FD98631;
    address public constant USDT = 0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2;
    address public constant DOLA = 0x4621b7A9c75199271F773Ebd9A499dbd165c3191;

    address public constant TOKENA = 0x940181a94A35A4569E4529A3CDfB74e38FD98631; // 0x7F62ac1e974D65Fab4A81821CA6AF659A5F46298

    // You'll need to replace these with actual addresses from the Aerodrome deployment
    address public constant USDC_WETH_POOL = 0xcDAC0d6c6C59727a65F871236188350531885C43;
    address public constant USDC_WETH_GAUGE = 0x519BBD1Dd8C6A94C46080E24f316c14Ee758C025;

    uint256 public constant INITIAL_BALANCE = 1_000_000 * 1e6; // 1 million USDC
    uint256 public constant INITIAL_ETH_BALANCE = 1000 ether;
    uint256 public constant INITIAL_AERO_BALANCE = 10_000 ether;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));

        connector = new AerodromeConnector("AerodromeConnector", 1, address(1));

        vm.deal(ALICE, INITIAL_ETH_BALANCE);
        deal(USDC, ALICE, INITIAL_BALANCE);
        deal(WETH, ALICE, INITIAL_ETH_BALANCE);
        deal(USDT, ALICE, INITIAL_BALANCE);
        deal(AERO, ALICE, INITIAL_AERO_BALANCE);
        deal(DOLA, ALICE, INITIAL_ETH_BALANCE);
        deal(TOKENA, ALICE, INITIAL_AERO_BALANCE);

        vm.startPrank(ALICE);
        IERC20(USDC).approve(address(connector), type(uint256).max);
        IERC20(WETH).approve(address(connector), type(uint256).max);
        IERC20(USDC_WETH_POOL).approve(address(connector), type(uint256).max);
        IERC20(USDT).approve(address(connector), type(uint256).max);
        IERC20(AERO).approve(address(connector), type(uint256).max);
        IERC20(DOLA).approve(address(connector), type(uint256).max);
        IERC20(TOKENA).approve(address(connector), type(uint256).max);
        vm.stopPrank();
    }

    function _quoteDepositLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 a,
        uint256 b,
        bool balance,
        uint256 slippage
    ) internal returns (uint256 amountA, uint256 amountB) {
        vm.warp(block.timestamp - 15);
        (amountA, amountB) = connector.quoteDepositLiquidity(tokenA, tokenB, stable, a, b, balance);
        amountA = amountA * (10_000 - slippage) / 10_000;
        amountB = amountB * (10_000 - slippage) / 10_000;
        vm.warp(block.timestamp + 15);
    }

    function _dealAndApprove(address tokenA, address tokenB, uint256 a, uint256 b, address toApprove) internal {
        deal(tokenA, ALICE, a);
        deal(tokenB, ALICE, b);

        vm.startPrank(ALICE);
        IERC20(tokenA).approve(toApprove, a);
        IERC20(tokenB).approve(toApprove, b);
        vm.stopPrank();
    }

    function testAddLiquidity() public {
        uint256 slippage = 60; // 0.6%
        uint256 deadline = block.timestamp + 1 hours;

        // Change these params to change the pool, tokens, amounts
        uint256 amountADesired = 10_000e18; // 100 tokenA
        uint256 amountBDesired = 10_000e18; // 1 tokenB
        address tokenA = 0x4621b7A9c75199271F773Ebd9A499dbd165c3191;
        address tokenB = 0xD5B9dDB04f20eA773C9b56607250149B26049B1F;
        bool stable = true;
        bool balanceRatio = false;

        _dealAndApprove(tokenA, tokenB, amountADesired, amountBDesired, address(connector));

        (uint256 amountAMin, uint256 amountBMin) =
            _quoteDepositLiquidity(tokenA, tokenB, stable, amountADesired, amountBDesired, balanceRatio, slippage);

        console.log("mins given: A:%e, B:%e", amountAMin, amountBMin);

        vm.startPrank(ALICE);

        console.log("TOKENA balance before: %s", IERC20(tokenA).balanceOf(ALICE));
        console.log("WETH balance before: %s", IERC20(tokenB).balanceOf(ALICE));

        bytes memory data = abi.encodeWithSelector(
            IRouter.addLiquidity.selector,
            tokenA,
            tokenB,
            stable,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            balanceRatio,
            ALICE,
            deadline
        );

        address pool = IPoolFactory(AERODROME_FACTORY).getPool(tokenA, tokenB, stable);

        console.log("Liquidity balance of Alice before deposit", IERC20(pool).balanceOf(ALICE));

        bytes memory result = connector.execute(data);
        (uint256 amountA, uint256 amountB, uint256 liquidity) = abi.decode(result, (uint256, uint256, uint256));

        console.log("Liquidity added: %e tokenA, %e tokenB", amountA, amountB);
        console.log("Liquidity balance of Alice after deposit: %e", IERC20(pool).balanceOf(ALICE));

        vm.stopPrank();
    }

    function test_manipulatePrice_addLiquidity() public {
        uint256 amountADesired = 100e18; // 100 AERO
        uint256 amountBDesired = 1 ether; // 1 WETH

        address tokenA = TOKENA;
        address tokenB = WETH;
        bool stable = false;
        bool balanceRatio = true;

        uint256 slippage = 60; // 0.6%
        uint256 deadline = block.timestamp + 1 hours;

        (uint256 amountAMin, uint256 amountBMin) =
            _quoteDepositLiquidity(tokenA, tokenB, stable, amountADesired, amountBDesired, balanceRatio, slippage);

        // manipulate price
        address manipulator = makeAddr("manipulator");
        deal(tokenB, manipulator, 100e18);
        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route({from: tokenB, to: tokenA, stable: stable, factory: AERODROME_FACTORY});
        vm.startPrank(manipulator);
        IERC20(tokenB).approve(address(AERODROME_ROUTER), 100e18);
        IRouter(AERODROME_ROUTER).swapExactTokensForTokens(100e18, 0, routes, manipulator, block.timestamp + 60);

        // add liquidity
        vm.startPrank(ALICE);
        bytes memory data = abi.encodeWithSelector(
            IRouter.addLiquidity.selector,
            tokenA,
            tokenB,
            stable,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            balanceRatio, // swap to balance
            ALICE,
            deadline
        );

        address pool = IPoolFactory(AERODROME_FACTORY).getPool(tokenA, tokenB, stable);

        vm.expectRevert(AerodromeUtils.AerodromeUtils_ExceededMaxSlippage.selector);
        bytes memory result = connector.execute(data);

        vm.stopPrank();
    }

    function test_fuzz_addLiquidity(uint256 amountA, uint256 amountB) public {
        uint256 amountADesired = 1e18 + amountA % (INITIAL_ETH_BALANCE / 100 - 1e18); // 1e13 tokenA
        uint256 amountBDesired = 1e18 + amountB % (INITIAL_ETH_BALANCE / 100 - 1e18); // up to 10 ETH
        uint256 deadline = block.timestamp + 1 hours;
        uint256 slippage = 50; // 0.5%

        address tokenA = TOKENA;
        address tokenB = WETH;
        bool stable = false;
        bool balanceRatio = false;

        (uint256 amountAMin, uint256 amountBMin) =
            _quoteDepositLiquidity(tokenA, tokenB, stable, amountADesired, amountBDesired, balanceRatio, slippage);

        vm.startPrank(ALICE);

        bytes memory data = abi.encodeWithSelector(
            IRouter.addLiquidity.selector,
            tokenA,
            tokenB,
            stable,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            balanceRatio,
            ALICE,
            deadline
        );

        address pool = IPoolFactory(AERODROME_FACTORY).getPool(tokenA, tokenB, stable);
        console.log("Liquidity balance of Alice before deposit: %e", IERC20(pool).balanceOf(ALICE));

        bytes memory result = connector.execute(data);
        (uint256 amountA, uint256 amountB, uint256 liquidity) = abi.decode(result, (uint256, uint256, uint256));

        console.log("Liquidity added: %e tokenA, %e tokenB", amountA, amountB);
        console.log("Liquidity balance of Alice after deposit: %e", IERC20(pool).balanceOf(ALICE));

        vm.stopPrank();
    }

    // weth/usdc fuzz test
    function test_fuzz_weth_addLiquidity(uint256 amountA, uint256 amountB) public {
        uint256 amountADesired = bound(amountA, 1e4, INITIAL_BALANCE / 10); // 100,000 USDC
        uint256 amountBDesired = bound(amountB, 1e13, INITIAL_ETH_BALANCE / 20); // 50 ETH
        uint256 deadline = block.timestamp + 1 hours;
        uint256 slippage = 60; // 0.6%

        address tokenA = USDC;
        address tokenB = WETH;
        bool stable = false;
        bool balanceRatio = false;

        (uint256 amountAMin, uint256 amountBMin) =
            _quoteDepositLiquidity(tokenA, tokenB, stable, amountADesired, amountBDesired, balanceRatio, slippage);

        vm.startPrank(ALICE);

        bytes memory data = abi.encodeWithSelector(
            IRouter.addLiquidity.selector,
            tokenA,
            tokenB,
            stable,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            balanceRatio,
            ALICE,
            deadline
        );

        address pool = IPoolFactory(AERODROME_FACTORY).getPool(tokenA, tokenB, stable);

        console.log("Liquidity balance of Alice before deposit: %e", IERC20(pool).balanceOf(ALICE));

        bytes memory result = connector.execute(data);
        (uint256 amountA, uint256 amountB, uint256 liquidity) = abi.decode(result, (uint256, uint256, uint256));

        console.log("Liquidity added: %e tokenA, %e tokenB", amountA, amountB);
        console.log("Liquidity balance of Alice after deposit: %e", IERC20(pool).balanceOf(ALICE));

        vm.stopPrank();
    }

    function tset_USDC_addLiquidity() public {
        uint256 amountADesired = 10_000e6;
        uint256 amountBDesired = 50e18;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 slippage = 60; // 0.6%

        address tokenA = USDC;
        address tokenB = WETH;
        bool stable = false;
        bool balanceRatio = false;

        (uint256 amountAMin, uint256 amountBMin) =
            _quoteDepositLiquidity(tokenA, tokenB, stable, amountADesired, amountBDesired, balanceRatio, slippage);

        vm.startPrank(ALICE);

        bytes memory data = abi.encodeWithSelector(
            IRouter.addLiquidity.selector,
            tokenA,
            tokenB,
            stable,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            balanceRatio,
            ALICE,
            deadline
        );

        address pool = IPoolFactory(AERODROME_FACTORY).getPool(tokenA, tokenB, stable);

        console.log("Liquidity balance of Alice before deposit: %e", IERC20(pool).balanceOf(ALICE));

        bytes memory result = connector.execute(data);
        (uint256 amountA, uint256 amountB, uint256 liquidity) = abi.decode(result, (uint256, uint256, uint256));

        console.log("Liquidity added: %e tokenA, %e tokenB", amountA, amountB);
        console.log("Liquidity balance of Alice after deposit: %e", IERC20(pool).balanceOf(ALICE));

        vm.stopPrank();
    }

    function test_fuzz_aero_addLiquidity(uint256 amountA, uint256 amountB) public {
        uint256 amountADesired = 100_000 + amountA % (INITIAL_BALANCE / 3 - 100_000); // Up to 333k USDC
        uint256 amountBDesired = 1e17 + amountB % (INITIAL_ETH_BALANCE * 100 - 1e17); // Up to 100k AERO
        deal(AERO, ALICE, amountBDesired);
        uint256 deadline = block.timestamp + 1 hours;
        uint256 slippage = 60; // 0.6%

        address tokenA = USDC;
        address tokenB = AERO;
        bool stable = false;
        bool balanceRatio = false;

        (uint256 amountAMin, uint256 amountBMin) =
            _quoteDepositLiquidity(tokenA, tokenB, stable, amountADesired, amountBDesired, balanceRatio, slippage);

        vm.startPrank(ALICE);

        bytes memory data = abi.encodeWithSelector(
            IRouter.addLiquidity.selector,
            tokenA,
            tokenB,
            stable,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            balanceRatio,
            ALICE,
            deadline
        );

        address pool = IPoolFactory(AERODROME_FACTORY).getPool(tokenA, tokenB, stable);

        console.log("Liquidity balance of Alice before deposit: %e", IERC20(pool).balanceOf(ALICE));

        bytes memory result = connector.execute(data);
        (uint256 amountA, uint256 amountB, uint256 liquidity) = abi.decode(result, (uint256, uint256, uint256));

        console.log("Liquidity added: %e tokenA, %e tokenB", amountA, amountB);
        console.log("Liquidity balance of Alice after deposit: %e", IERC20(pool).balanceOf(ALICE));

        vm.stopPrank();
    }

    function test_aero_addLiquidity() public {
        uint256 amountADesired = INITIAL_BALANCE / 10; // 100k USDC
        uint256 amountBDesired = INITIAL_AERO_BALANCE; //  10k AERO

        uint256 deadline = block.timestamp + 1 hours;
        uint256 slippage = 60; // 0.6%

        address tokenA = USDC;
        address tokenB = AERO;
        bool stable = false;
        bool balanceRatio = false;

        (uint256 amountAMin, uint256 amountBMin) =
            _quoteDepositLiquidity(tokenA, tokenB, stable, amountADesired, amountBDesired, balanceRatio, slippage);
        console.log("mins given: A:%e, B:%e", amountAMin, amountBMin);

        vm.startPrank(ALICE);

        bytes memory data = abi.encodeWithSelector(
            IRouter.addLiquidity.selector,
            tokenA,
            tokenB,
            stable,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            balanceRatio,
            ALICE,
            deadline
        );

        address pool = IPoolFactory(AERODROME_FACTORY).getPool(tokenA, tokenB, stable);

        console.log("Liquidity balance of Alice before deposit: %e", IERC20(pool).balanceOf(ALICE));

        bytes memory result = connector.execute(data);
        (uint256 amountA, uint256 amountB, uint256 liquidity) = abi.decode(result, (uint256, uint256, uint256));

        console.log("Liquidity added: %e tokenA, %e tokenB", amountA, amountB);
        console.log("Liquidity balance of Alice after deposit: %e", IERC20(pool).balanceOf(ALICE));

        vm.stopPrank();
    }

    // Testing the DOLA/USDC basic stable pair
    function test_fuzz_dola_addLiquidity(uint256 a, uint256 b) public {
        uint256 amountADesired = bound(a, 1e5, INITIAL_BALANCE / 10 - 1e5); // USDC
        uint256 amountBDesired = bound(b, 1e17, INITIAL_ETH_BALANCE / 10 - 1e17); // DOLA

        uint256 deadline = block.timestamp + 1 hours;
        uint256 slippage = 60; // 0.6%

        address tokenA = USDC;
        address tokenB = DOLA;
        bool stable = true;
        bool balanceRatio = false;

        (uint256 amountAMin, uint256 amountBMin) =
            _quoteDepositLiquidity(tokenA, tokenB, stable, amountADesired, amountBDesired, balanceRatio, slippage);

        vm.startPrank(ALICE);

        bytes memory data = abi.encodeWithSelector(
            IRouter.addLiquidity.selector,
            tokenA,
            tokenB,
            stable,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            balanceRatio,
            ALICE,
            deadline
        );

        address pool = IPoolFactory(AERODROME_FACTORY).getPool(tokenA, tokenB, stable);

        console.log("Liquidity balance of Alice before deposit: %e", IERC20(pool).balanceOf(ALICE));

        bytes memory result = connector.execute(data);
        (uint256 amountA, uint256 amountB, uint256 liquidity) = abi.decode(result, (uint256, uint256, uint256));

        console.log("Liquidity added: %e tokenA, %e tokenB", amountA, amountB);
        console.log("Liquidity balance of Alice after deposit: %e", IERC20(pool).balanceOf(ALICE));
        vm.stopPrank();
    }

    function test_dola_addLiquidity() public {
        uint256 amountADesired = 10_000e6; // USDC
        uint256 amountBDesired = 50e18; // DOLA

        uint256 deadline = block.timestamp + 1 hours;
        uint256 slippage = 60; // 0.6%

        address tokenA = USDC;
        address tokenB = DOLA;
        bool stable = true;
        bool balanceRatio = false;

        (uint256 amountAMin, uint256 amountBMin) =
            _quoteDepositLiquidity(tokenA, tokenB, stable, amountADesired, amountBDesired, balanceRatio, slippage);

        vm.startPrank(ALICE);

        bytes memory data = abi.encodeWithSelector(
            IRouter.addLiquidity.selector,
            tokenA,
            tokenB,
            stable,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            balanceRatio,
            ALICE,
            deadline
        );

        address pool = IPoolFactory(AERODROME_FACTORY).getPool(tokenA, tokenB, stable);

        console.log("Liquidity balance of Alice before deposit: %e", IERC20(pool).balanceOf(ALICE));

        bytes memory result = connector.execute(data);
        (uint256 amountA, uint256 amountB, uint256 liquidity) = abi.decode(result, (uint256, uint256, uint256));

        console.log("Liquidity added: %e tokenA, %e tokenB", amountA, amountB);
        console.log("Liquidity balance of Alice after deposit: %e", IERC20(pool).balanceOf(ALICE));
        vm.stopPrank();
    }

    // This test passes since the issue is fixed
    function test_incorrectMath_causesRevert() public {
        uint256 amountADesired = 0;
        uint256 amountBDesired = 1e9; // 1000 USDC. Some should get swapped to WETH
        uint256 deadline = block.timestamp + 1 hours;
        uint256 slippage = 60; // 0.6%

        address tokenA = WETH;
        address tokenB = USDC;
        bool stable = false;
        bool balanceRatio = true;

        (uint256 amountAMin, uint256 amountBMin) =
            _quoteDepositLiquidity(tokenA, tokenB, stable, amountADesired, amountBDesired, balanceRatio, slippage);

        vm.startPrank(ALICE);

        bytes memory data = abi.encodeWithSelector(
            IRouter.addLiquidity.selector,
            tokenA,
            tokenB,
            stable,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            balanceRatio,
            ALICE,
            deadline
        );

        bytes memory result = connector.execute(data);
        vm.stopPrank();
    }

    function testRemoveLiquidity() public {
        // First, add liquidity
        tset_USDC_addLiquidity();

        // Now remove liquidity
        address pair = IPoolFactory(AERODROME_FACTORY).getPool(USDC, WETH, false);
        require(pair != address(0), "Pair does not exist");

        uint256 liquidity = IERC20(pair).balanceOf(ALICE);
        console.log("liquidity is %e", liquidity);
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

        try connector.execute(data) returns (bytes memory result) {
            (uint256 amountA, uint256 amountB) = abi.decode(result, (uint256, uint256));

            console.log("Liquidity removed: %s USDC, %s WETH", amountA, amountB);

            assertGt(amountA, 0, "Amount A should be greater than 0");
            assertGt(amountB, 0, "Amount B should be greater than 0");
        } catch Error(string memory reason) {
            console.log("Error: %s", reason);
            assertTrue(false, "Remove liquidity should not revert");
        } catch (bytes memory lowLevelData) {
            console.logBytes(lowLevelData);
            assertTrue(false, "Remove liquidity should not revert");
        }

        console.log("LP token balance after: %s", IERC20(pair).balanceOf(ALICE));
        console.log("TOKENA balance after: %s", IERC20(TOKENA).balanceOf(ALICE));
        console.log("WETH balance after: %s", IERC20(WETH).balanceOf(ALICE));

        vm.stopPrank();
    }

    function testSwapExactTokensForTokens() public {
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

        bytes memory result = connector.execute(data);
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

    function testDepositToGauge() public {
        // First, add liquidity to get LP tokens
        tset_USDC_addLiquidity();

        uint256 lpBalance = IERC20(USDC_WETH_POOL).balanceOf(ALICE);
        require(lpBalance > 0, "No LP tokens to deposit");

        uint256 depositAmount = lpBalance / 2; // Deposit half of the LP tokens

        vm.startPrank(ALICE);

        // Approve the AerodromeConnector to spend LP tokens
        IERC20(USDC_WETH_POOL).approve(address(connector), depositAmount);

        bytes memory data = abi.encodeWithSelector(IGauge.deposit.selector, USDC_WETH_GAUGE, depositAmount);

        connector.execute(data);

        assertEq(IGauge(USDC_WETH_GAUGE).balanceOf(ALICE), depositAmount, "Gauge balance should match deposit amount");
        assertEq(IERC20(USDC_WETH_POOL).balanceOf(ALICE), lpBalance - depositAmount, "LP token balance should decrease");

        vm.stopPrank();
    }

    function testInvalidSelector() public {
        bytes memory data = abi.encodeWithSelector(bytes4(keccak256("invalidFunction()")));

        vm.expectRevert(abi.encodeWithSelector(AerodromeConnector.InvalidSelector.selector));
        connector.execute(data);
    }
}
