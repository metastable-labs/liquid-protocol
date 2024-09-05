// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "forge-std/Test.sol";
import "../../src/connectors/base/uniswap/v2/main.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract UniswapV2ConnectorTest is Test {
    UniswapV2Connector public connector;
    address public constant ALICE = address(0x1);

    address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public constant UNISWAP_V2_ROUTER = 0x4CF84C108eF9C9D4df63A2537703E827e5c3BEB2;
    address public constant UNISWAP_V2_FACTORY = 0x2A5767D9C914B2a1dB7a5F02Cc5716dcF42D6d5c;
    address public constant WETH = 0x4200000000000000000000000000000000000006;

    uint256 public constant INITIAL_BALANCE = 1_000_000 * 1e6; // 1 million USDC
    uint256 public constant INITIAL_ETH_BALANCE = 1000 ether;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));

        connector = new UniswapV2Connector("UniswapV2Connector", 1);

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

    function testAddLiquidityETH() public {
        uint256 amountTokenDesired = 1000 * 1e6; // 100,000 USDC
        uint256 amountTokenMin = 990 * 1e6;
        uint256 amountETHMin = 0.1 ether;
        uint256 amountETH = 1 ether;
        uint256 deadline = block.timestamp + 1 hours;

        vm.startPrank(ALICE);

        bytes memory data = abi.encodeWithSelector(
            IUniswapV2Router02.addLiquidityETH.selector,
            ALICE,
            ALICE,
            USDC,
            amountTokenDesired,
            amountTokenMin,
            amountETHMin,
            deadline
        );

        bytes memory result = connector.execute{value: amountETH}(data);
        (uint256 amountToken, uint256 amountETHAdded, uint256 liquidity) =
            abi.decode(result, (uint256, uint256, uint256));

        assertGt(amountToken, 0, "Amount token should be greater than 0");
        assertGt(amountETHAdded, 0, "Amount ETH should be greater than 0");
        assertGt(liquidity, 0, "Liquidity should be greater than 0");

        vm.stopPrank();
    }

    function testRemoveLiquidityETH() public {
        // First, add liquidity ETH
        testAddLiquidityETH();

        // Now remove liquidity ETH
        address pair = IUniswapV2Factory(UNISWAP_V2_FACTORY).getPair(WETH, USDC);
        require(pair == address(0), "Pair does not exist");

        uint256 liquidity = IERC20(pair).balanceOf(ALICE);
        require(liquidity > 0, "No liquidity to remove");

        // uint256 amountTokenMin = 1;
        // uint256 amountETHMin = 1;
        // uint256 deadline = block.timestamp + 1 hours;

        // vm.startPrank(ALICE);

        // bytes memory data = abi.encodeWithSelector(
        //     IUniswapV2Router02.removeLiquidityETH.selector,
        //     ALICE,
        //     ALICE,
        //     USDC,
        //     liquidity,
        //     amountTokenMin,
        //     amountETHMin,
        //     deadline
        // );

        // uint256 aliceETHBalanceBefore = ALICE.balance;
        // uint256 aliceUSDCBalanceBefore = IERC20(USDC).balanceOf(ALICE);

        // bytes memory result = connector.execute(data);
        // (uint256 amountToken, uint256 amountETH) = abi.decode(result, (uint256, uint256));

        // uint256 aliceETHBalanceAfter = ALICE.balance;
        // uint256 aliceUSDCBalanceAfter = IERC20(USDC).balanceOf(ALICE);

        // assertGt(amountToken, 0, "Amount token should be greater than 0");
        // assertGt(amountETH, 0, "Amount ETH should be greater than 0");
        // assertEq(aliceETHBalanceAfter - aliceETHBalanceBefore, amountETH, "ETH balance mismatch");
        // assertEq(aliceUSDCBalanceAfter - aliceUSDCBalanceBefore, amountToken, "USDC balance mismatch");

        // vm.stopPrank();
    }

    function testFail_InvalidSelector() public {
        bytes memory data = abi.encodeWithSelector(bytes4(keccak256("invalidFunction()")));

        vm.expectRevert(UniswapV2Connector.InvalidSelector.selector);
        connector.execute(data);
    }

    function testFail_DeadlineExpired() public {
        uint256 amountTokenDesired = 100_000 * 1e6;
        uint256 amountTokenMin = 99_000 * 1e6;
        uint256 amountETHMin = 0.1 ether;
        uint256 amountETH = 1 ether;
        uint256 deadline = block.timestamp - 1; // Expired deadline

        vm.startPrank(ALICE);

        bytes memory data = abi.encodeWithSelector(
            IUniswapV2Router02.addLiquidityETH.selector,
            USDC,
            amountTokenDesired,
            amountTokenMin,
            amountETHMin,
            ALICE,
            deadline
        );

        vm.expectRevert(UniswapV2Connector.DeadlineExpired.selector);
        connector.execute{value: amountETH}(data);

        vm.stopPrank();
    }

    function testFail_InsufficientLiquidity() public {
        uint256 amountTokenDesired = 1; // Very small amount
        uint256 amountTokenMin = 1;
        uint256 amountETHMin = 1;
        uint256 amountETH = 1;
        uint256 deadline = block.timestamp + 1 hours;

        vm.startPrank(ALICE);

        bytes memory data = abi.encodeWithSelector(
            IUniswapV2Router02.addLiquidityETH.selector,
            USDC,
            amountTokenDesired,
            amountTokenMin,
            amountETHMin,
            ALICE,
            deadline
        );

        vm.expectRevert(UniswapV2Connector.InsufficientLiquidity.selector);
        connector.execute{value: amountETH}(data);

        vm.stopPrank();
    }

    receive() external payable {}
}
