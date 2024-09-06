// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
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
        deal(WETH, ALICE, INITIAL_ETH_BALANCE);

        vm.startPrank(ALICE);
        IERC20(USDC).approve(address(connector), type(uint256).max);
        IERC20(WETH).approve(address(connector), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(address(connector));
        IERC20(WETH).approve(AERODROME_ROUTER, type(uint256).max);
        IERC20(USDC).approve(AERODROME_ROUTER, type(uint256).max);
        vm.stopPrank();
    }

    function testAddLiquidity() public {
        uint256 amountADesired = 1000 * 1e6; // 1,000 USDC
        uint256 amountBDesired = 1 ether; // 1 WETH
        uint256 amountAMin = 900 * 1e6;
        uint256 amountBMin = 0.9 ether;
        bool stable = false;
        uint256 deadline = block.timestamp + 1 hours;

        vm.startPrank(ALICE);

        console.log("USDC balance before: %s", IERC20(USDC).balanceOf(ALICE));
        console.log("WETH balance before: %s", IERC20(WETH).balanceOf(ALICE));

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

        console.log("Liquidity added: %s USDC, %s WETH, %s LP", amountA, amountB, liquidity);

        assertGt(amountA, 0, "Amount A should be greater than 0");
        assertGt(amountB, 0, "Amount B should be greater than 0");
        assertGt(liquidity, 0, "Liquidity should be greater than 0");

        console.log("USDC balance after: %s", IERC20(USDC).balanceOf(ALICE));
        console.log("WETH balance after: %s", IERC20(WETH).balanceOf(ALICE));

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
        console.log("USDC balance after: %s", IERC20(USDC).balanceOf(ALICE));
        console.log("WETH balance after: %s", IERC20(WETH).balanceOf(ALICE));

        vm.stopPrank();
    }

    function testInvalidSelector() public {
        bytes memory data = abi.encodeWithSelector(bytes4(keccak256("invalidFunction()")));

        vm.expectRevert(abi.encodeWithSelector(AerodromeConnector.InvalidSelector.selector));
        connector.execute(data);
    }
}
