// SPDX-License-Identifier: GNU
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {BaseConnector} from "../../../../../BaseConnector.sol";
import {Constants} from "../../../../common/constant.sol";
import "../../../../../interface/IConnector.sol";
import "../../../../../curators/interface/IStrategy.sol";
import "../../../../../curators/interface/IEngine.sol";
import "../../../../../curators/interface/IOracle.sol";
import "./interface.sol";
import "./events.sol";

contract MoonwellConnector is BaseConnector, Constants, MoonwellEvents {
    /* ========== STATE VARIABLES ========== */

    /// @notice Oracle contract fetches the price of different tokens
    ILiquidStrategy public immutable strategyModule;

    /// @notice Engine contract
    IEngine public immutable engine;

    /// @notice Oracle contract fetches the price of different tokens
    IOracle public immutable oracle;

    /// @notice Initializes the MoonwellConnector
    /// @param name Name of the Connector
    /// @param connectorType Type of connector
    constructor(string memory name, ConnectorType connectorType, address a, address b, address c)
        BaseConnector(name, connectorType)
    {
        strategyModule = ILiquidStrategy(a);
        engine = IEngine(b);
        oracle = IOracle(c);
    }

    // TODO: only the execution engine should be able to call this execute method
    // TODO: add methods for fee withdrawal and unstaking
    /// @notice Executes an action
    function execute(
        ActionType actionType,
        address[] memory assetsIn,
        uint256[] memory amounts,
        address assetOut,
        uint256 amountRatio,
        bytes32 strategyId,
        address userAddress,
        bytes calldata data
    ) external payable override returns (uint256) {
        require(address(engine) == msg.sender, "caller is not the execution engine");

        if (actionType == IConnector.ActionType.SUPPLY) {
            return _mintToken(assetsIn[0], assetOut, amounts[0], strategyId, userAddress);
        } else if (actionType == IConnector.ActionType.BORROW) {
            return _borrowToken(assetsIn, assetOut, amounts[0], amountRatio, strategyId, userAddress);
        }
        // else if (actionType == IConnector.ActionType.SWAP) {
        //     uint256[] memory amounts = _swapExactTokensForTokens(data, executionEngine);
        //     return abi.encode(amounts);
        // } else if (actionType == IConnector.ActionType.STAKE) {
        //     return _depositToGauge(data, executionEngine);
        // }
        // revert InvalidAction();
    }

    function _mintToken(address assetIn, address assetOut, uint256 amount, bytes32 strategyId, address userAddress)
        internal
        returns (uint256)
    {
        // approve and supply asset
        ERC20(assetIn).approve(assetOut, amount);
        // 0=success
        uint256 success = MErc20Interface(assetOut).mint(amount);
        if (success != 0) revert();

        // update user info
        address[] memory underlyingTokens = new address[](1);
        underlyingTokens[0] = assetIn;

        uint256 shareAmount = ERC20(assetOut).balanceOf(address(this));

        uint256[] memory underlyingAmounts = new uint256[](1);
        underlyingAmounts[0] = amount;

        (int256 _priceInUsd,) = _tokenAandTokenBPriceInUsd(assetIn, address(0));
        uint256 amountInUsd = (uint256(_priceInUsd) * amount) / 10 ** ERC20(assetIn).decimals();

        strategyModule.updateUserStats(
            strategyId,
            userAddress,
            assetIn,
            COMPTROLLER,
            assetOut,
            underlyingTokens,
            amount,
            amountInUsd,
            shareAmount,
            underlyingAmounts
        );

        // returns the balance of `assetOut`
        return shareAmount;
    }

    function _borrowToken(
        address[] memory assetsIn,
        address assetOut,
        uint256 amount,
        uint256 amountRatio,
        bytes32 strategyId,
        address userAddress
    ) internal returns (uint256) {
        // expects 3: assetsIn [token(cbBtc), collateralToken(mw_cbBtc), borrowContract(mw_usdc)]

        // to borrow, first enter market by calling enterMarkets in comptroller
        address[] memory mTokens = new address[](1);
        mTokens[0] = assetsIn[1];
        ComptrollerInterface(COMPTROLLER).enterMarkets(mTokens);

        // to borrow
        uint256 currentTokenAToBPrice =
            _getOneTokenAPriceInTokenB(assetsIn[0], assetOut) / 10 ** 18 - ERC20(assetOut).decimals();
        uint256 suppliedAmount = (amount * currentTokenAToBPrice) / 10 ** ERC20(assetsIn[0]).decimals();
        uint256 amountToBorrow = (suppliedAmount * amountRatio) / 10_000;
        uint256 success = MErc20Interface(assetsIn[2]).borrow(amountToBorrow);
        if (success != 0) revert();

        // update user info
        address[] memory underlyingTokens = new address[](1);
        underlyingTokens[0] = assetsIn[0];

        uint256[] memory underlyingAmounts = new uint256[](1);
        underlyingAmounts[0] = amount;

        strategyModule.updateUserStats(
            strategyId,
            userAddress,
            assetsIn[1],
            COMPTROLLER,
            assetOut,
            underlyingTokens,
            0,
            0,
            amountToBorrow,
            underlyingAmounts
        );

        // returns the balance of `assetOut`
        return amountToBorrow;
    }

    // Helper function
    function _getOneTokenAPriceInTokenB(address _tokenA, address _tokenB) internal returns (uint256) {
        (int256 _tokenAPriceInUsd, int256 _tokenBPriceInUsd) = _tokenAandTokenBPriceInUsd(_tokenA, _tokenB);

        return oracle.getTokenAPriceInTokenB(uint256(_tokenAPriceInUsd), 8, uint256(_tokenBPriceInUsd), 8);
    }

    function _tokenAandTokenBPriceInUsd(address _tokenA, address _tokenB) internal returns (int256, int256) {
        int256 _tokenAPriceInUsd;
        int256 _tokenBPriceInUsd;

        // Get tokenA price in USD
        if (_tokenA == CBBTC) _tokenAPriceInUsd = oracle.getLatestAnswer(SEQUENCER_UPTIME_FEED, CBBTC_USD);
        if (_tokenA == DAI) _tokenAPriceInUsd = oracle.getLatestAnswer(SEQUENCER_UPTIME_FEED, DAI_USD);
        if (_tokenA == ETH) _tokenAPriceInUsd = oracle.getLatestAnswer(SEQUENCER_UPTIME_FEED, ETH_USD);
        if (_tokenA == USDC) _tokenAPriceInUsd = oracle.getLatestAnswer(SEQUENCER_UPTIME_FEED, USDC_USD);

        // Get tokenB price in USD
        if (_tokenB == CBBTC) _tokenBPriceInUsd = oracle.getLatestAnswer(SEQUENCER_UPTIME_FEED, CBBTC_USD);
        if (_tokenB == DAI) _tokenBPriceInUsd = oracle.getLatestAnswer(SEQUENCER_UPTIME_FEED, DAI_USD);
        if (_tokenB == ETH) _tokenBPriceInUsd = oracle.getLatestAnswer(SEQUENCER_UPTIME_FEED, ETH_USD);
        if (_tokenB == USDC) _tokenBPriceInUsd = oracle.getLatestAnswer(SEQUENCER_UPTIME_FEED, USDC_USD);

        return (_tokenAPriceInUsd, _tokenBPriceInUsd);
    }
}
