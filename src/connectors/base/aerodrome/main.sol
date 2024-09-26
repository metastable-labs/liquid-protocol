// SPDX-License-Identifier: GNU
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IRouter} from "@aerodrome/contracts/contracts/interfaces/IRouter.sol";
import {IPool} from "@aerodrome/contracts/contracts/interfaces/IPool.sol";
import {IPoolFactory} from "@aerodrome/contracts/contracts/interfaces/factories/IPoolFactory.sol";

import "../../../BaseConnector.sol";
import "../common/constant.sol";
import "./utils.sol";
import "./interface.sol";
import "./events.sol";

contract AerodromeConnector is BaseConnector, Constants, AerodromeEvents {
    IRouter public immutable aerodromeRouter;
    IPoolFactory public immutable aerodromeFactory;

    error ExecutionFailed(string reason);

    error InvalidSelector();
    error DeadlineExpired();
    error InsufficientLiquidity();
    error SlippageExceeded();
    error UnauthorizedCaller();

    /// @notice Initializes the AerodromeConnector
    /// @param name Name of the connector
    /// @param version Version of the connector
    constructor(string memory name, uint256 version) BaseConnector(name, version) {
        aerodromeRouter = IRouter(AERODROME_ROUTER);
        aerodromeFactory = IPoolFactory(AERODROME_FACTORY);
    }

    receive() external payable {}

    /// @notice Executes a function call on the Aerodrome protocol
    /// @dev This function handles both addLiquidity and removeLiquidity operations
    /// @param data The calldata for the function call
    /// @return bytes The return data from the function call
    function execute(bytes calldata data) external payable override returns (bytes memory) {
        bytes4 selector = bytes4(data[:4]);

        if (selector == aerodromeRouter.addLiquidity.selector) {
            (uint256 amountA, uint256 amountB, uint256 liquidity) = _depositBasicLiquidity(data, msg.sender);
            return abi.encode(amountA, amountB, liquidity);
        } else if (selector == aerodromeRouter.removeLiquidity.selector) {
            (uint256 amountA, uint256 amountB) = _removeBasicLiquidity(data, msg.sender);
            return abi.encode(amountA, amountB);
        } else if (selector == aerodromeRouter.swapExactTokensForTokens.selector) {
            uint256[] memory amounts = _swapExactTokensForTokens(data, msg.sender);
            return abi.encode(amounts);
        } else if (selector == this.execute.selector) {
            // This is the case for gauge and pool operations
            (address target, bytes memory callData) = abi.decode(data[4:], (address, bytes));
            return _executeExternalCall(abi.encode(target, callData, msg.sender));
        }

        revert InvalidSelector();
    }

    function _swapExactTokensForTokens(bytes calldata data, address caller)
        internal
        returns (uint256[] memory amounts)
    {
        (uint256 amountIn, uint256 minReturnAmount, IRouter.Route[] memory routes, address to, uint256 deadline) =
            abi.decode(data[4:], (uint256, uint256, IRouter.Route[], address, uint256));

        if (block.timestamp > deadline) revert DeadlineExpired();

        address tokenIn = routes[0].from;
        address tokenOut = routes[routes.length - 1].to;

        // Calculate expected output
        uint256[] memory expectedAmounts = aerodromeRouter.getAmountsOut(amountIn, routes);
        uint256 expectedAmountOut = expectedAmounts[expectedAmounts.length - 1];

        // Check if the expected output meets the minimum return amount
        if (expectedAmountOut < minReturnAmount) {
            revert SlippageExceeded();
        }

        // Transfer tokens from caller to this contract
        IERC20(tokenIn).transferFrom(caller, address(this), amountIn);

        // Approve router to spend tokens
        IERC20(tokenIn).approve(address(aerodromeRouter), amountIn);

        // Perform the swap
        amounts = aerodromeRouter.swapExactTokensForTokens(amountIn, minReturnAmount, routes, to, deadline);

        if (amounts[amounts.length - 1] < minReturnAmount) {
            revert SlippageExceeded();
        }

        emit Swapped(tokenIn, tokenOut, amounts[0], amounts[amounts.length - 1]);

        return amounts;
    }

    /// @notice Deposits liquidity into an Aerodrome pool
    /// @dev Handles the process of adding liquidity, including price checks and token swaps
    /// @param data The calldata containing function parameters
    /// @param caller The original caller of this function
    /// @return amountAOut The amount of tokenA actually deposited
    /// @return amountBOut The amount of tokenB actually deposited
    /// @return liquidity The amount of liquidity tokens received
    function _depositBasicLiquidity(bytes calldata data, address caller)
        internal
        returns (uint256 amountAOut, uint256 amountBOut, uint256 liquidity)
    {
        (
            address tokenA,
            address tokenB,
            bool stable,
            uint256 amountADesired,
            uint256 amountBDesired,
            uint256 amountAMin,
            uint256 amountBMin,
            address to,
            uint256 deadline
        ) = abi.decode(data[4:], (address, address, bool, uint256, uint256, uint256, uint256, address, uint256));

        if (block.timestamp > deadline) revert DeadlineExpired();

        // Transfer tokens from msg.sender to this contract
        IERC20(tokenA).transferFrom(caller, address(this), amountADesired);
        IERC20(tokenB).transferFrom(caller, address(this), amountBDesired);

        require(IERC20(tokenA).balanceOf(address(this)) >= amountADesired, "Insufficient tokenA balance");
        require(IERC20(tokenB).balanceOf(address(this)) >= amountBDesired, "Insufficient tokenB balance");

        // Check price ratio
        AerodromeUtils.checkPriceRatio(
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            stable,
            address(aerodromeRouter),
            address(aerodromeFactory),
            LIQ_SLIPPAGE
        );

        // Balance token ratio before depositing
        (uint256[] memory amounts, bool sellTokenA) = AerodromeUtils.balanceTokenRatio(
            tokenA, tokenB, amountADesired, amountBDesired, stable, address(aerodromeRouter)
        );

        // Update token amounts after swaps
        if (sellTokenA) {
            amountADesired -= amounts[0];
            amountBDesired += amounts[1];
        } else {
            amountBDesired -= amounts[0];
            amountADesired += amounts[1];
        }

        // For volatile pairs: calculate minimum amount out with 0.5% slippage
        if (!stable) {
            amountAMin = AerodromeUtils.mulDiv(amountADesired, 10_000 - LIQ_SLIPPAGE, 10_000);
            amountBMin = AerodromeUtils.mulDiv(amountBDesired, 10_000 - LIQ_SLIPPAGE, 10_000);
        }

        // Add liquidity to the basic pool
        (amountAOut, amountBOut, liquidity) = aerodromeRouter.addLiquidity(
            tokenA, tokenB, stable, amountADesired, amountBDesired, amountAMin, amountBMin, to, deadline
        );

        if (liquidity == 0) revert InsufficientLiquidity();

        uint256 leftoverA = amountADesired - amountAOut;
        uint256 leftoverB = amountBDesired - amountBOut;

        AerodromeUtils.returnLeftovers(tokenA, tokenB, leftoverA, leftoverB, msg.sender, WETH_ADDRESS);

        emit LiquidityAdded(tokenA, tokenB, amountAOut, amountBOut, liquidity);
    }

    /// @notice Removes liquidity from an Aerodrome pool
    /// @dev Handles the process of removing liquidity and receiving tokens
    /// @param data The calldata containing function parameters
    /// @param caller The original caller of this function
    /// @return amountA The amount of tokenA received
    /// @return amountB The amount of tokenB received
    function _removeBasicLiquidity(bytes calldata data, address caller)
        internal
        returns (uint256 amountA, uint256 amountB)
    {
        (
            address tokenA,
            address tokenB,
            bool stable,
            uint256 liquidity,
            uint256 amountAMin,
            uint256 amountBMin,
            address to,
            uint256 deadline
        ) = abi.decode(data[4:], (address, address, bool, uint256, uint256, uint256, address, uint256));

        if (block.timestamp > deadline) revert DeadlineExpired();

        // Get the pair address
        address pair = aerodromeFactory.getPool(tokenA, tokenB, stable);
        if (pair == address(0)) revert("Pair does not exist");

        // Approve the router to spend the liquidity tokens
        IERC20(pair).approve(address(aerodromeRouter), liquidity);

        // Transfer liquidity tokens from the smart wallet to this contract
        IERC20(pair).transferFrom(caller, address(this), liquidity);

        (amountA, amountB) =
            aerodromeRouter.removeLiquidity(tokenA, tokenB, stable, liquidity, amountAMin, amountBMin, to, deadline);

        if (amountA < amountAMin || amountB < amountBMin) {
            revert SlippageExceeded();
        }

        emit LiquidityRemoved(tokenA, tokenB, amountA, amountB, liquidity);
    }

    /// @notice Executes an external call to a gauge or pool contract
    /// @param data The calldata containing the function call details
    /// @return bytes The result of the external call
    function _executeExternalCall(bytes memory data) internal returns (bytes memory) {
        (address target, bytes memory callData, address caller) = abi.decode(data, (address, bytes, address));

        bytes4 selector = bytes4(callData[:4]);

        if (selector == IGauge.deposit.selector) {
            uint256 amount = abi.decode(callData[4:], (uint256));
            IGauge(target).deposit(amount);
            emit LPTokenStaked(target, amount);
        } else if (selector == IGauge.withdraw.selector) {
            uint256 amount = abi.decode(callData[4:], (uint256));
            IGauge(target).withdraw(amount);
            emit LPTokenUnStaked(target, amount);
        } else if (selector == IGauge.getReward.selector) {
            IGauge(target).getReward(caller);
            emit AeroRewardsClaimed(target, address(IGauge(target).rewardToken()));
        } else if (selector == IPool.claimFees.selector) {
            IPool(target).claimFees();
            emit FeesWithdrawn(target);
        } else {
            revert InvalidSelector();
        }

        return new bytes(0);
    }
}
