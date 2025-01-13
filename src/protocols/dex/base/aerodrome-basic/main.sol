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

    /// @notice Thrown when asset out is not the same as pool address
    error AssetOutNotPool();

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
        address assetOut,
        uint256 stepIndex,
        uint256 amountRatio,
        bytes32 strategyId,
        address userAddress,
        bytes calldata data
    )
        external
        payable
        override
        onlyEngine
        returns (address, address[] memory, uint256[] memory, address, uint256, address[] memory, uint256[] memory)
    {
        if (actionType == ActionType.SUPPLY) {
            return _depositBasicLiquidity(strategyId, userAddress, assetsIn, assetOut, amountRatio, data);
        } else if (actionType == ActionType.WITHDRAW) {
            return _removeBasicLiquidity(strategyId, userAddress, assetsIn, assetOut, amountRatio, stepIndex, data);
        }
        // else if (actionType == ActionType.SWAP) {
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
    function withdrawAsset(bytes32 _strategyId, address _user, address _token) external onlyEngine returns (bool) {
        uint256 tokenBalance = strategyModule.getUserTokenBalance(_strategyId, _user, _token);

        require(strategyModule.transferToken(_token, tokenBalance), "Not enough tokens for withdrawal");
        return ERC20(_token).transfer(_user, tokenBalance);
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

        // if (block.timestamp > deadline) revert DeadlineExpired();

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
    /// @param strategyId The id of the strategy
    /// @param userAddress The user's address
    /// @param assetsIn The encoded parameters for the desired action
    /// @param assetOut The address of the lp token
    /// @param amountRatio The percentage of the amount to use
    /// @param data The data
    function _depositBasicLiquidity(
        bytes32 strategyId,
        address userAddress,
        address[] memory assetsIn,
        address assetOut,
        uint256 amountRatio,
        bytes calldata data
    )
        internal
        returns (address, address[] memory, uint256[] memory, address, uint256, address[] memory, uint256[] memory)
    {
        uint256 amountAUsed;
        uint256 amountBUsed;
        uint256 liquidityDeposited;

        (bool stable, bool balanceTokenRatio) = abi.decode(data, (bool, bool));

        address tokenA = assetsIn[0];
        address tokenB = assetsIn[1];
        uint256 amountA = strategyModule.getUserTokenBalance(strategyId, userAddress, tokenA);
        uint256 amountB = strategyModule.getUserTokenBalance(strategyId, userAddress, tokenB);
        uint256 deadline = block.timestamp + 100;

        address pool = aerodromeFactory.getPool(tokenA, tokenB, stable);
        if (pool == address(0)) revert PoolDoesNotExist();
        if (pool != assetOut) revert AssetOutNotPool();

        uint256 amountAIn = (amountRatio * amountA) / 10_000;
        uint256 amountBIn = (amountRatio * amountB) / 10_000;

        // transfer tokenA and tokenB from Strategy Module
        require(strategyModule.transferToken(tokenA, amountAIn), "Not enough tokenA");
        require(strategyModule.transferToken(tokenB, amountBIn), "Not enough tokenB");

        uint256[] memory assetsInAmounts = new uint256[](2);
        assetsInAmounts[0] = amountA;
        assetsInAmounts[1] = amountB;

        // update balance
        strategyModule.updateUserTokenBalance(strategyId, userAddress, tokenA, amountAIn, 1);
        strategyModule.updateUserTokenBalance(strategyId, userAddress, tokenB, amountBIn, 1);

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

        // return left overs to strategy
        if (amountALeft > 0 && _transferToken(tokenA, amountALeft)) {
            strategyModule.updateUserTokenBalance(strategyId, userAddress, tokenA, amountALeft, 0);
        }
        if (amountBLeft > 0 && _transferToken(tokenB, amountBLeft)) {
            strategyModule.updateUserTokenBalance(strategyId, userAddress, tokenB, amountBLeft, 0);
        }

        // update lp balance
        strategyModule.updateUserTokenBalance(strategyId, userAddress, assetOut, liquidityDeposited, 0);

        emit LiquidityAdded(tokenA, tokenB, amountAUsed, amountBUsed, liquidityDeposited);

        uint256[] memory underlyingAmounts = new uint256[](2);
        underlyingAmounts[0] = amountAUsed;
        underlyingAmounts[1] = amountBUsed;

        // return
        return (AERODROME_ROUTER, assetsIn, assetsInAmounts, assetOut, liquidityDeposited, assetsIn, underlyingAmounts);
    }

    /// @notice Removes liquidity from an Aerodrome pool
    /// @dev Handles the process of removing liquidity and receiving tokens
    /// @param strategyId The id of the strategy
    /// @param userAddress The user's address
    /// @param assetsIn The encoded parameters for the desired action
    /// @param assetOut The address of the lp token
    /// @param amountRatio The percentage of the amount to use
    /// @param stepIndex The current strategy step index
    /// @param data The data
    function _removeBasicLiquidity(
        bytes32 strategyId,
        address userAddress,
        address[] memory assetsIn,
        address assetOut,
        uint256 amountRatio,
        uint256 stepIndex,
        bytes calldata data
    )
        internal
        returns (address, address[] memory, uint256[] memory, address, uint256, address[] memory, uint256[] memory)
    {
        (bool stable, bool balanceTokenRatio) = abi.decode(data, (bool, bool));
        uint256 deadline = block.timestamp + 100;

        // get userShareBalance of current step
        ILiquidStrategy.ShareBalance memory userShareBalance =
            strategyModule.getUserShareBalance(strategyId, userAddress, AERODROME_ROUTER, assetsIn[0], stepIndex);

        uint256 lpBalance = userShareBalance.shareAmount;
        address tokenA = userShareBalance.underlyingTokens[0];
        address tokenB = userShareBalance.underlyingTokens[1];
        // uint256 amountAMin = userShareBalance.underlyingAmounts[0];
        // uint256 amountBMin = userShareBalance.underlyingAmounts[1];
        uint256 amountAMin = 0;
        uint256 amountBMin = 0;

        address pool = aerodromeFactory.getPool(tokenA, tokenB, stable);
        if (pool == address(0)) revert PoolDoesNotExist();
        if (pool != assetsIn[0]) revert AssetOutNotPool();

        // transfer token from Strategy Module
        require(strategyModule.transferToken(assetsIn[0], lpBalance), "not enough borrowed token");

        // update balance
        strategyModule.updateUserTokenBalance(strategyId, userAddress, assetsIn[0], lpBalance, 1);

        // ERC20(pool).transferFrom(caller, address(this), liquidity);
        ERC20(pool).approve(address(aerodromeRouter), lpBalance);

        (uint256 amountA, uint256 amountB) = aerodromeRouter.removeLiquidity(
            tokenA, tokenB, stable, lpBalance, amountAMin, amountBMin, address(strategyModule), deadline
        );

        strategyModule.updateUserTokenBalance(strategyId, userAddress, tokenA, amountA, 0);
        strategyModule.updateUserTokenBalance(strategyId, userAddress, tokenB, amountB, 0);

        emit LiquidityRemoved(tokenA, tokenB, amountA, amountB, lpBalance);

        return (AERODROME_ROUTER, new address[](0), new uint256[](0), address(0), 0, new address[](0), new uint256[](0));
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

    /// @notice Transfers tokens to the strategyModule contract
    function _transferToken(address _token, uint256 _amount) internal returns (bool) {
        return ERC20(_token).transfer(address(strategyModule), _amount);
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
