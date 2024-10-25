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

    error IncorrectETHAmount();
    error PoolDoesNotExist();

    /// @notice Initializes the AerodromeConnector
    /// @param name Name of the connector
    /// @param version Version of the connector
    constructor(string memory name, uint256 version, address plugin) BaseConnector(name, version, plugin) {
        aerodromeRouter = IRouter(AERODROME_ROUTER);
        aerodromeFactory = IPoolFactory(AERODROME_FACTORY);
    }

    receive() external payable {}

    function execute(bytes calldata data) external payable override returns (bytes memory) {
        return execute(data, msg.sender);
    } 

    /// @notice Executes a function call on the Aerodrome protocol
    /// @dev This function handles both addLiquidity and removeLiquidity operations
    /// @param data The calldata for the function call
    /// @return bytes The return data from the function call
    function execute(bytes calldata data, address caller) public payable returns (bytes memory) {
        // Extract the original caller (smart wallet) address from the end of the data
        address originalCaller = msg.sender == _plugin ? caller : msg.sender;
        
        bytes4 selector = bytes4(data[:4]);

        if (selector == aerodromeRouter.addLiquidity.selector) {
            (uint256 amountA, uint256 amountB, uint256 liquidity) = _depositBasicLiquidity(data, originalCaller);
            return abi.encode(amountA, amountB, liquidity);
        } else if (selector == aerodromeRouter.removeLiquidity.selector) {
            (uint256 amountA, uint256 amountB) = _removeBasicLiquidity(data, originalCaller);
            return abi.encode(amountA, amountB);
        } else if (selector == aerodromeRouter.swapExactTokensForTokens.selector) {
            uint256[] memory amounts = _swapExactTokensForTokens(data, originalCaller);
            return abi.encode(amounts);
        } else if (selector == IGauge.deposit.selector) {
            return _depositToGauge(data, originalCaller);
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

        _receiveTokensFromCaller(tokenIn, amountIn, address(0), 0, caller);

        IERC20(tokenIn).approve(address(aerodromeRouter), amountIn);

        address tokenOut = routes[routes.length - 1].to;

        uint256[] memory expectedAmounts = aerodromeRouter.getAmountsOut(amountIn, routes);
        uint256 expectedAmountOut = expectedAmounts[expectedAmounts.length - 1];

        if (expectedAmountOut < minReturnAmount) {
            revert SlippageExceeded();
        }

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
    /// @return amountAUsed The amount of tokenA actually deposited
    /// @return amountBUsed The amount of tokenB actually deposited
    /// @return liquidityDeposited The amount of liquidity tokens received
    function _depositBasicLiquidity(bytes calldata data, address caller)
        internal
        returns (uint256 amountAUsed, uint256 amountBUsed, uint256 liquidityDeposited)
    {
        (
            address tokenA,
            address tokenB,
            bool stable,
            uint256 amountAIn,
            uint256 amountBIn,
            uint256 amountAMin,
            uint256 amountBMin,
            bool swapToBalanceTokens,
            address to,
            uint256 deadline
        ) = abi.decode(data[4:], (address, address, bool, uint256, uint256, uint256, uint256, bool, address, uint256));

        if (block.timestamp > deadline) revert DeadlineExpired();

        address pool = aerodromeFactory.getPool(tokenA, tokenB, stable);
        if (pool == address(0)) revert PoolDoesNotExist();
         
        _receiveTokensFromCaller(tokenA, amountAIn, tokenB, amountBIn, caller);

        uint256 ratioBefore = AerodromeUtils.reserveRatio(pool);
                
        uint256 amountALeft = amountAIn;
        uint256 amountBLeft = amountBIn;
        
        for (uint256 i = 0; i < 2; i++) {
            (uint256[] memory amounts, bool sellTokenA) = AerodromeUtils.balanceTokenRatio(
                tokenA, tokenB, amountALeft, amountBLeft, stable
            );

            (amountALeft, amountBLeft) = AerodromeUtils.updateAmountsIn(amountALeft, amountBLeft, sellTokenA, amounts);

            // Approve tokens to router
            IERC20(tokenA).approve(address(aerodromeRouter), amountALeft);
            IERC20(tokenB).approve(address(aerodromeRouter), amountBLeft);

            (uint256 amountADeposited, uint256 amountBDeposited, uint256 liquidity) = aerodromeRouter.addLiquidity(
                tokenA, tokenB, stable, amountALeft, amountBLeft, 0, 0, to, deadline // 0 amountOutMin because we do checkValueOut()
            );

            amountALeft -= amountADeposited;
            amountBLeft -= amountBDeposited;

            amountAUsed += amountADeposited;
            amountBUsed += amountBDeposited;

            liquidityDeposited += liquidity;

            if (!stable) break; // only iterate once for volatile pairs
        }
        AerodromeUtils.checkPriceImpact(pool, ratioBefore);

        AerodromeUtils.checkValueOut(liquidityDeposited, tokenA, tokenB, stable, amountAMin, amountBMin, amountAIn, amountBIn);

        AerodromeUtils.returnLeftovers(tokenA, tokenB, amountALeft, amountBLeft, caller);
        
        emit LiquidityAdded(tokenA, tokenB, amountAUsed, amountBUsed, liquidityDeposited);
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

        address pool = aerodromeFactory.getPool(tokenA, tokenB, stable);
        if (pool == address(0)) revert PoolDoesNotExist();

        IERC20(pool).transferFrom(caller, address(this), liquidity);
        IERC20(pool).approve(address(aerodromeRouter), liquidity);

        (amountA, amountB) =
            aerodromeRouter.removeLiquidity(tokenA, tokenB, stable, liquidity, amountAMin, amountBMin, to, deadline);

        emit LiquidityRemoved(tokenA, tokenB, amountA, amountB, liquidity);
    }

    /// @notice Deposits LP tokens into a gauge
    /// @param data The calldata containing function parameters
    /// @return bytes The encoded result of the deposit
    function _depositToGauge(bytes calldata data, address caller) internal returns (bytes memory) {
        (address gaugeAddress, uint256 amount) = abi.decode(data[4:], (address, uint256));

        address lpToken = IGauge(gaugeAddress).stakingToken();

        IERC20(lpToken).transferFrom(caller, address(this), amount);
        IERC20(lpToken).approve(gaugeAddress, amount);

        IGauge(gaugeAddress).deposit(amount, caller);

        emit LPTokenStaked(gaugeAddress, amount);
        return abi.encode(amount, caller);
    }

    function _receiveTokensFromCaller(address tokenA, uint256 amountA, address tokenB, uint256 amountB, address caller) internal {
        if (amountA > 0) {
            if (tokenA == WETH && msg.value > 0) {
                if (msg.value != amountA) revert IncorrectETHAmount();

                IWETH(WETH).deposit{value: msg.value}();
            }
            else {
                IERC20(tokenA).transferFrom(caller, address(this), amountA);
            }
        }
        if (amountB > 0) {
            if (tokenB == WETH && msg.value > 0) {
                if (msg.value != amountB) revert IncorrectETHAmount();

                IWETH(WETH).deposit{value: msg.value}();
            }
            else {
                IERC20(tokenB).transferFrom(caller, address(this), amountB);
            }
        }
    }

    function quoteDepositLiquidity(
        address tokenA, 
        address tokenB, 
        bool stable, 
        uint256 amountA, 
        uint256 amountB,
        bool balanceTokenRatio
    ) external view returns(uint256 amountAOut, uint256 amountBOut) {
        (amountAOut, amountBOut) =  AerodromeUtils.quoteDepositLiquidity(tokenA, tokenB, stable, amountA, amountB, balanceTokenRatio);
    }
}
