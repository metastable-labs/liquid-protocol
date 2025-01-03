// SPDX-License-Identifier: GNU
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {IRouter} from "@aerodrome/contracts/contracts/interfaces/IRouter.sol";
import {IPool} from "@aerodrome/contracts/contracts/interfaces/IPool.sol";
import {IPoolFactory} from "@aerodrome/contracts/contracts/interfaces/factories/IPoolFactory.sol";

import {BaseConnector} from "../../../../BaseConnector.sol";
import {Constants} from "../../../common/constant.sol";
import {AerodromeUtils} from "./utils.sol";
import "../../../../curators/interface/IStrategy.sol";
import "../../../../curators/interface/IEngine.sol";
import "../../../../curators/interface/IOracle.sol";
import "./interface.sol";
import "./events.sol";

contract AerodromeBasicConnector is BaseConnector, Constants, AerodromeEvents {
    /* ========== STATE VARIABLES ========== */

    /// @notice Router contract for executing Aerodrome trades and liquidity operations
    IRouter public immutable aerodromeRouter;

    /// @notice Factory contract for creating and managing Aerodrome pools
    IPoolFactory public immutable aerodromeFactory;

    /// @notice Oracle contract fetches the price of different tokens
    ILiquidStrategy public immutable strategyModule;

    /// @notice Engine contract
    IEngine public immutable engine;

    /// @notice Oracle contract fetches the price of different tokens
    IOracle public immutable oracle;

    /* ========== ERRORS ========== */

    /// @notice Thrown when execution fails with a specific reason
    error ExecutionFailed(string reason);

    /// @notice Thrown when an invalid action type is provided
    error InvalidAction();

    /// @notice Thrown when transaction deadline has passed
    error DeadlineExpired();

    /// @notice Thrown when pool has insufficient liquidity
    error InsufficientLiquidity();

    /// @notice Thrown when slippage tolerance is exceeded
    error SlippageExceeded();

    /// @notice Thrown when caller is not authorized
    error UnauthorizedCaller();

    /// @notice Thrown when ETH amount doesn't match the required amount
    error IncorrectETHAmount();

    /// @notice Thrown when trying to interact with a non-existent pool
    error PoolDoesNotExist();

    /// @notice Initializes the AerodromeConnector
    /// @param name Name of the Connector
    /// @param connectorType Type of connector
    constructor(string memory name, ConnectorType connectorType, address _strategy, address _engine, address _oracle)
        BaseConnector(name, connectorType)
    {
        aerodromeRouter = IRouter(AERODROME_ROUTER);
        aerodromeFactory = IPoolFactory(AERODROME_FACTORY);

        strategyModule = ILiquidStrategy(_strategy);
        engine = IEngine(_engine);
        oracle = IOracle(_oracle);
    }

    modifier onlyEngine() {
        require(msg.sender == address(engine), "caller is not the execution engine");
        _;
    }

    receive() external payable {}

    // TODO: only the execution engine should be able to call this execute method
    // TODO: add methods for fee withdrawal and unstaking
    /// @notice Executes an action
    function execute(
        ActionType actionType,
        address[] memory assetsIn,
        uint256[] memory amounts,
        address assetOut,
        uint256 stepIndex,
        uint256 amountRatio,
        bytes32 strategyId,
        address userAddress,
        // uint256 prevLoopAmountOut,
        bytes calldata data
    )
        external
        payable
        override
        onlyEngine
        returns (address, address[] memory, uint256[] memory, address, uint256, address[] memory, uint256[] memory)
    {
        if (actionType == ActionType.SUPPLY) {
            return _depositBasicLiquidity(assetsIn, amounts, amountRatio, data);
            // return abi.encode(amountA, amountB, liquidity);
            // return ();
        }
        // else if (actionType == ActionType.WITHDRAW) {
        //     (uint256 amountA, uint256 amountB) = _removeBasicLiquidity(data, executionEngine);
        //     // return abi.encode(amountA, amountB);
        //     return 1;
        // } else if (actionType == ActionType.SWAP) {
        //     uint256[] memory amounts = _swapExactTokensForTokens(data, executionEngine);
        //     // return abi.encode(amounts);
        //     return 1;
        // } else if (actionType == ActionType.STAKE) {
        //     // return _depositToGauge(data, executionEngine);
        //     return 1;
        // }
        // revert InvalidAction();
    }

    /// @notice Initially updates the user token balance
    function initialTokenBalanceUpdate(bytes32 strategyId, address userAddress, address token, uint256 amount)
        external
        onlyEngine
    {
        strategyModule.updateUserTokenBalance(strategyId, userAddress, token, amount, 0);
    }

    /// @notice Withdraw user asset
    function withdrawAsset(address _user, address _token, uint256 _amount) external onlyEngine returns (bool) {
        require(strategyModule.transferToken(_token, _amount), "");
        return ERC20(_token).transfer(_user, _amount);
    }

    /// @notice Swaps exact tokens for tokens on the Aerodrome protocol
    /// @param data The encoded parameters for the desired action
    /// @param caller The address of the original caller
    /// @return amounts The amounts of tokens received for each step of the swap
    function _swapExactTokensForTokens(bytes calldata data, address caller)
        internal
        returns (uint256[] memory amounts)
    {
        (uint256 amountIn, uint256 minReturnAmount, IRouter.Route[] memory routes, address to, uint256 deadline) =
            abi.decode(data[4:], (uint256, uint256, IRouter.Route[], address, uint256));

        if (block.timestamp > deadline) revert DeadlineExpired();

        address tokenIn = routes[0].from;

        _receiveTokensFromCaller(tokenIn, amountIn, address(0), 0, caller);

        ERC20(tokenIn).approve(address(aerodromeRouter), amountIn);

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
    /// @param assetsIn The encoded parameters for the desired action
    /// @param amountsIn The original caller of this function
    /// @param amountRatio The original caller of this function
    /// @param data The original caller of this function
    function _depositBasicLiquidity(
        address[] memory assetsIn,
        uint256[] memory amountsIn,
        uint256 amountRatio,
        bytes calldata data
    )
        internal
        returns (address, address[] memory, uint256[] memory, address, uint256, address[] memory, uint256[] memory)
    {
        uint256 amountAUsed;
        uint256 amountBUsed;
        uint256 liquidityDeposited;

        (bool stable, bool balanceTokenRatio, uint256 deadline) = abi.decode(data[4:], (bool, bool, uint256));

        address tokenA = assetsIn[0];
        address tokenB = assetsIn[1];
        uint256 amountAIn = amountsIn[0];
        uint256 amountBIn = amountsIn[1];

        if (block.timestamp > deadline) revert DeadlineExpired();

        address pool = aerodromeFactory.getPool(tokenA, tokenB, stable);
        if (pool == address(0)) revert PoolDoesNotExist();

        _receiveTokensFromCaller(tokenA, amountAIn, tokenB, amountBIn, msg.sender);

        uint256 ratioBefore = AerodromeUtils.reserveRatio(pool);

        uint256 amountALeft = amountAIn;
        uint256 amountBLeft = amountBIn;

        // Balance token ratios
        for (uint256 i = 0; i < 2; i++) {
            if (balanceTokenRatio) {
                (uint256[] memory amounts, bool sellTokenA) =
                    AerodromeUtils.balanceTokenRatio(tokenA, tokenB, amountALeft, amountBLeft, stable);

                (amountALeft, amountBLeft) =
                    AerodromeUtils.updateAmountsIn(amountALeft, amountBLeft, sellTokenA, amounts);
            }
            // Approve tokens to router
            ERC20(tokenA).approve(address(aerodromeRouter), amountALeft);
            ERC20(tokenB).approve(address(aerodromeRouter), amountBLeft);

            (uint256 amountADeposited, uint256 amountBDeposited, uint256 liquidity) = aerodromeRouter.addLiquidity(
                tokenA,
                tokenB,
                stable,
                amountALeft,
                amountBLeft,
                0,
                0,
                address(strategyModule),
                deadline // 0 amountOutMin because we do checkValueOut()
            );

            amountALeft -= amountADeposited;
            amountBLeft -= amountBDeposited;

            amountAUsed += amountADeposited;
            amountBUsed += amountBDeposited;

            liquidityDeposited += liquidity;

            if (!stable || !balanceTokenRatio) break; // only iterate once for volatile pairs, or if not balancing token ratio
        }
        AerodromeUtils.checkPriceImpact(pool, ratioBefore);

        AerodromeUtils.checkValueOut(liquidityDeposited, tokenA, tokenB, stable, 0, 0, amountAIn, amountBIn);

        AerodromeUtils.returnLeftovers(tokenA, tokenB, amountALeft, amountBLeft, address(strategyModule));

        emit LiquidityAdded(tokenA, tokenB, amountAUsed, amountBUsed, liquidityDeposited);

        // re
    }

    /// @notice Removes liquidity from an Aerodrome pool
    /// @dev Handles the process of removing liquidity and receiving tokens
    /// @param data The encoded parameters for the desired action
    /// @param caller The address of the original caller
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

        ERC20(pool).transferFrom(caller, address(this), liquidity);
        ERC20(pool).approve(address(aerodromeRouter), liquidity);

        (amountA, amountB) =
            aerodromeRouter.removeLiquidity(tokenA, tokenB, stable, liquidity, amountAMin, amountBMin, to, deadline);

        emit LiquidityRemoved(tokenA, tokenB, amountA, amountB, liquidity);
    }

    /// @notice Deposits LP tokens into a gauge
    /// @param data The encoded parameters for the desired action
    /// @param caller The address of the original caller
    /// @return bytes The encoded result of the deposit
    function _depositToGauge(bytes calldata data, address caller) internal returns (bytes memory) {
        (address gaugeAddress, uint256 amount) = abi.decode(data[4:], (address, uint256));

        address lpToken = IGauge(gaugeAddress).stakingToken();

        ERC20(lpToken).transferFrom(caller, address(this), amount);
        ERC20(lpToken).approve(gaugeAddress, amount);

        IGauge(gaugeAddress).deposit(amount, caller);

        emit LPTokenStaked(gaugeAddress, amount);
        return abi.encode(amount, caller);
    }

    /// @notice Transfers tokens from the caller to the contract
    function _receiveTokensFromCaller(address tokenA, uint256 amountA, address tokenB, uint256 amountB, address caller)
        internal
    {
        if (amountA > 0) {
            if (tokenA == WETH && msg.value > 0) {
                if (msg.value != amountA) revert IncorrectETHAmount();

                IWETH(WETH).deposit{value: msg.value}();
            } else {
                ERC20(tokenA).transferFrom(caller, address(this), amountA);
            }
        }
        if (amountB > 0) {
            if (tokenB == WETH && msg.value > 0) {
                if (msg.value != amountB) revert IncorrectETHAmount();

                IWETH(WETH).deposit{value: msg.value}();
            } else {
                ERC20(tokenB).transferFrom(caller, address(this), amountB);
            }
        }
    }

    /// @notice Quotes the expected amounts of token A and token B to deposit in a liquidity pool
    /// @param tokenA The address of token A
    /// @param tokenB The address of token B
    /// @param stable Indicates whether the pair is a stable pair
    /// @param amountA The amount of token A being deposited
    /// @param amountB The amount of token B being deposited
    /// @param balanceTokenRatio Indicates whether to balance the token ratio with a swap
    /// @return amountAOut The amount of token A expected to be deposited
    /// @return amountBOut The amount of token B expected to be deposited
    function quoteDepositLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 amountA,
        uint256 amountB,
        bool balanceTokenRatio
    ) external view returns (uint256 amountAOut, uint256 amountBOut) {
        (amountAOut, amountBOut) =
            AerodromeUtils.quoteDepositLiquidity(tokenA, tokenB, stable, amountA, amountB, balanceTokenRatio);
    }
}
