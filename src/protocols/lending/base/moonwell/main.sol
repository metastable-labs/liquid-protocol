// SPDX-License-Identifier: GNU
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {BaseConnector} from "../../../../BaseConnector.sol";
import {Constants} from "../../../common/constant.sol";
import "../../../../interface/IConnector.sol";
import "../../../../curators/interface/IStrategy.sol";
import "../../../../curators/interface/IEngine.sol";
import "../../../../curators/interface/IOracle.sol";
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
    constructor(string memory name, ConnectorType connectorType, address _strategy, address _engine, address _oracle)
        BaseConnector(name, connectorType)
    {
        strategyModule = ILiquidStrategy(_strategy);
        engine = IEngine(_engine);
        oracle = IOracle(_oracle);
    }

    modifier onlyEngine() {
        require(msg.sender == address(engine), "caller is not the execution engine");
        _;
    }

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
        bytes calldata data
    )
        external
        payable
        override
        onlyEngine
        returns (address, address[] memory, uint256[] memory, address, uint256, address[] memory, uint256[] memory)
    {
        if (actionType == IConnector.ActionType.SUPPLY) {
            return _mintToken(assetsIn[0], assetOut, amounts[0]);
        } else if (actionType == IConnector.ActionType.BORROW) {
            return _borrowToken(assetsIn, assetOut, amounts[0], amountRatio, strategyId, userAddress, stepIndex);
        } else if (actionType == IConnector.ActionType.REPAY) {
            return _repayBorrowToken(assetsIn, strategyId, userAddress, stepIndex);
        } else if (actionType == IConnector.ActionType.WITHDRAW) {
            return _withdrawToken(assetsIn, assetOut, strategyId, userAddress, stepIndex);
        }
        // revert InvalidAction();
    }

    function _mintToken(address assetIn, address assetOut, uint256 amount)
        internal
        returns (address, address[] memory, uint256[] memory, address, uint256, address[] memory, uint256[] memory)
    {
        // approve and supply asset
        ERC20(assetIn).approve(assetOut, amount);
        // 0=success
        uint256 success = MErc20Interface(assetOut).mint(amount);
        if (success != 0) revert();

        address[] memory underlyingTokens = new address[](1);
        underlyingTokens[0] = assetIn;

        uint256 shareAmount = ERC20(assetOut).balanceOf(address(this));

        uint256[] memory underlyingAmounts = new uint256[](1);
        underlyingAmounts[0] = amount;

        // transfer token to Strategy Module
        require(_transferToken(assetOut, shareAmount), "Invalid token amount");

        return (
            COMPTROLLER, underlyingTokens, underlyingAmounts, assetOut, shareAmount, underlyingTokens, underlyingAmounts
        );
    }

    function _borrowToken(
        address[] memory assetsIn,
        address assetOut,
        uint256 amount,
        uint256 amountRatio,
        bytes32 strategyId,
        address userAddress,
        uint256 stepIndex
    )
        internal
        returns (address, address[] memory, uint256[] memory, address, uint256, address[] memory, uint256[] memory)
    {
        // expects 3 assetsIn: e.g [token(cbBtc), collateralToken(mw_cbBtc), borrowMwContract(mw_usdc)]

        // get collateral token balance
        ILiquidStrategy.ShareBalance memory userShareBalance =
            strategyModule.getUserShareBalance(strategyId, userAddress, COMPTROLLER, assetsIn[1], stepIndex);
        uint256 ctBalance = userShareBalance.shareAmount;

        // transfer token from Strategy Module
        require(strategyModule.transferToken(assetsIn[1], ctBalance), "Not enough collateral token");

        // to borrow, first enter market by calling enterMarkets in comptroller
        address[] memory mTokens = new address[](1);
        mTokens[0] = assetsIn[1];
        ComptrollerInterface(COMPTROLLER).enterMarkets(mTokens);

        // borrow
        uint256 currentTokenAToBPrice =
            _getOneTokenAPriceInTokenB(assetsIn[0], assetOut) / 10 ** 18 - ERC20(assetOut).decimals();
        uint256 suppliedAmount = (amount * currentTokenAToBPrice) / 10 ** ERC20(assetsIn[0]).decimals();
        uint256 amountToBorrow = (suppliedAmount * amountRatio) / 10_000;
        uint256 success = MErc20Interface(assetsIn[2]).borrow(amountToBorrow);
        if (success != 0) revert();

        address[] memory assets = new address[](1);
        assets[0] = assetsIn[1];

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = ctBalance;

        address[] memory underlyingTokens = new address[](1);
        underlyingTokens[0] = assetsIn[0];

        uint256[] memory underlyingAmounts = new uint256[](1);
        underlyingAmounts[0] = amount;

        // transfer tokens to Strategy Module
        require(_transferToken(assetOut, amountToBorrow), "Invalid token amount");

        return (COMPTROLLER, assets, amounts, assetOut, amountToBorrow, underlyingTokens, underlyingAmounts);
    }

    function _repayBorrowToken(address[] memory assetsIn, bytes32 strategyId, address userAddress, uint256 stepIndex)
        internal
        returns (address, address[] memory, uint256[] memory, address, uint256, address[] memory, uint256[] memory)
    {
        // expects 3 assetsIn: e.g [token(usdc), collateralToken(mw_cbBtc), borrowMwContract(mw_usdc)]

        // get borrowed token balance
        ILiquidStrategy.ShareBalance memory userShareBalance =
            strategyModule.getUserShareBalance(strategyId, userAddress, COMPTROLLER, assetsIn[0], stepIndex);
        uint256 btBalance = userShareBalance.shareAmount;

        // get asset balance
        address[] memory assets = new address[](1);
        assets[0] = assetsIn[1];

        ILiquidStrategy.AssetBalance memory userAssetBalance =
            strategyModule.getUserAssetBalance(strategyId, userAddress, assets, stepIndex);

        // transfer token from Strategy Module
        require(strategyModule.transferToken(assetsIn[0], btBalance), "Not enough borrowed token");

        // repay
        ERC20(assetsIn[0]).approve(assetsIn[2], btBalance);
        uint256 status = MErc20Interface(assetsIn[2]).repayBorrow(btBalance);
        if (status != 0) revert();

        // exit market
        status = ComptrollerInterface(COMPTROLLER).exitMarket(assetsIn[1]);
        if (status != 0) revert();

        return (
            COMPTROLLER,
            userAssetBalance.assets,
            userAssetBalance.amounts,
            assetsIn[0],
            0,
            userShareBalance.underlyingTokens,
            userShareBalance.underlyingAmounts
        );
    }

    function _withdrawToken(
        address[] memory assetsIn,
        address assetOut,
        bytes32 strategyId,
        address userAddress,
        uint256 stepIndex
    )
        internal
        returns (address, address[] memory, uint256[] memory, address, uint256, address[] memory, uint256[] memory)
    {
        // get share token balance
        ILiquidStrategy.ShareBalance memory userShareBalance =
            strategyModule.getUserShareBalance(strategyId, userAddress, COMPTROLLER, assetsIn[0], stepIndex);
        uint256 stBalance = userShareBalance.shareAmount;

        // get underlying token balance
        address[] memory assets = new address[](1);
        assets[0] = assetOut;

        ILiquidStrategy.AssetBalance memory userAssetBalance =
            strategyModule.getUserAssetBalance(strategyId, userAddress, assets, stepIndex);
        uint256 utBalance = userAssetBalance.amounts[0];

        uint256 tokenBalanceBefore = ERC20(assetOut).balanceOf(address(this));

        // redeem
        ERC20(assetsIn[0]).approve(assetsIn[0], stBalance);
        uint256 status = MErc20Interface(assetsIn[0]).redeem(stBalance);
        if (status != 0) revert();

        uint256 tokenBalanceDiff = ERC20(assetOut).balanceOf(address(this)) - tokenBalanceBefore;

        // check that final withdraw amount is less than initial deposit
        require(tokenBalanceDiff <= utBalance, "taaaaaa");

        return (
            COMPTROLLER,
            userAssetBalance.assets,
            new uint256[](0),
            assetsIn[0],
            0,
            userShareBalance.underlyingTokens,
            new uint256[](0)
        );
    }

    // Helper function
    function _transferToken(address _token, uint256 _amount) internal returns (bool) {
        return ERC20(_token).transfer(address(strategyModule), _amount);
    }

    function _getOneTokenAPriceInTokenB(address _tokenA, address _tokenB) internal view returns (uint256) {
        (int256 _tokenAPriceInUsd, int256 _tokenBPriceInUsd) = _tokenAandTokenBPriceInUsd(_tokenA, _tokenB);

        return oracle.getTokenAPriceInTokenB(uint256(_tokenAPriceInUsd), 8, uint256(_tokenBPriceInUsd), 8);
    }

    function _tokenAandTokenBPriceInUsd(address _tokenA, address _tokenB) internal view returns (int256, int256) {
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
