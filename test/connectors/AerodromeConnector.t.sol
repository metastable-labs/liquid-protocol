// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/connectors/base/aerodrome/main.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IRouter} from "@aerodrome/contracts/contracts/interfaces/IRouter.sol";
import {IPoolFactory} from "@aerodrome/contracts/contracts/interfaces/factories/IPoolFactory.sol";

contract AerodromeConnectorTest is Test {
    AerodromeConnector public connector;
    address public constant ALICE = address(0x1);

    address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public constant AERODROME_ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address public constant AERODROME_FACTORY = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;
    address public constant WETH = 0x4200000000000000000000000000000000000006;

    uint256 public constant INITIAL_BALANCE = 1_000_000 * 1e6; // 1 million USDC
    uint256 public constant INITIAL_ETH_BALANCE = 1000 ether;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));

        connector = new AerodromeConnector("AerodromeConnector", 1);

        vm.deal(ALICE, INITIAL_ETH_BALANCE);
        deal(USDC, ALICE, INITIAL_BALANCE);

        vm.startPrank(ALICE);
        IERC20(USDC).transfer(address(connector), INITIAL_BALANCE / 2);

        // Transfer ETH to the connector
        (bool success,) = address(connector).call{value: INITIAL_ETH_BALANCE / 2}("");
        require(success, "ETH transfer failed");

        vm.stopPrank();

        // Verify balances
        assertEq(address(connector).balance, INITIAL_ETH_BALANCE / 2, "Connector ETH balance mismatch");
        assertEq(IERC20(USDC).balanceOf(address(connector)), INITIAL_BALANCE / 2, "Connector USDC balance mismatch");
    }

    function testAddLiquidity() public {
        uint256 amountADesired = 1000 * 1e6; // 1,000 USDC
        uint256 amountBDesired = 1 ether; // 1 WETH
        uint256 amountAMin = 990 * 1e6;
        uint256 amountBMin = 0.99 ether;
        bool stable = false;
        uint256 deadline = block.timestamp + 1 hours;

        vm.startPrank(ALICE);

        bytes memory data = abi.encodeWithSelector(
            IRouter.addLiquidity.selector,
            USDC,
            WETH,
            stable,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            ALICE,
            deadline
        );

        bytes memory result = connector.execute(data);
        (uint256 amountA, uint256 amountB, uint256 liquidity) = abi.decode(result, (uint256, uint256, uint256));

        assertGt(amountA, 0, "Amount A should be greater than 0");
        assertGt(amountB, 0, "Amount B should be greater than 0");
        assertGt(liquidity, 0, "Liquidity should be greater than 0");

        vm.stopPrank();
    }

    function testRemoveLiquidity() public {
        // First, add liquidity
        testAddLiquidity();

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

        IERC20(pair).approve(address(connector), liquidity);

        bytes memory data = abi.encodeWithSelector(
            IRouter.removeLiquidity.selector, USDC, WETH, stable, liquidity, amountAMin, amountBMin, ALICE, deadline
        );

        uint256 aliceUSDCBalanceBefore = IERC20(USDC).balanceOf(ALICE);
        uint256 aliceWETHBalanceBefore = IERC20(WETH).balanceOf(ALICE);

        bytes memory result = connector.execute(data);
        (uint256 amountA, uint256 amountB) = abi.decode(result, (uint256, uint256));

        uint256 aliceUSDCBalanceAfter = IERC20(USDC).balanceOf(ALICE);
        uint256 aliceWETHBalanceAfter = IERC20(WETH).balanceOf(ALICE);

        assertGt(amountA, 0, "Amount A should be greater than 0");
        assertGt(amountB, 0, "Amount B should be greater than 0");
        assertEq(aliceUSDCBalanceAfter - aliceUSDCBalanceBefore, amountA, "USDC balance mismatch");
        assertEq(aliceWETHBalanceAfter - aliceWETHBalanceBefore, amountB, "WETH balance mismatch");

        vm.stopPrank();
    }

    function testFail_InvalidSelector() public {
        bytes memory data = abi.encodeWithSelector(bytes4(keccak256("invalidFunction()")));

        vm.expectRevert(AerodromeConnector.InvalidSelector.selector);
        connector.execute(data);
    }

    function testFail_DeadlineExpired() public {
        uint256 amountADesired = 100_000 * 1e6;
        uint256 amountBDesired = 1 ether;
        uint256 amountAMin = 99_000 * 1e6;
        uint256 amountBMin = 0.99 ether;
        bool stable = false;
        uint256 deadline = block.timestamp - 1; // Expired deadline

        vm.startPrank(ALICE);

        bytes memory data = abi.encodeWithSelector(
            IRouter.addLiquidity.selector,
            USDC,
            WETH,
            stable,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            ALICE,
            deadline
        );

        vm.expectRevert(AerodromeConnector.DeadlineExpired.selector);
        connector.execute(data);

        vm.stopPrank();
    }

    function testFail_InsufficientLiquidity() public {
        uint256 amountADesired = 1; // Very small amount
        uint256 amountBDesired = 1;
        uint256 amountAMin = 1;
        uint256 amountBMin = 1;
        bool stable = false;
        uint256 deadline = block.timestamp + 1 hours;

        vm.startPrank(ALICE);

        bytes memory data = abi.encodeWithSelector(
            IRouter.addLiquidity.selector,
            USDC,
            WETH,
            stable,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            ALICE,
            deadline
        );

        vm.expectRevert(AerodromeConnector.InsufficientLiquidity.selector);
        connector.execute(data);

        vm.stopPrank();
    }

    receive() external payable {}
}
