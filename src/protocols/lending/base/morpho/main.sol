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

contract MorphConnector is BaseConnector, Constants, MorphEvents {
    /* ========== STATE VARIABLES ========== */

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

    /// @notice Initializes the MorphConnector
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
        address assetOut,
        uint256 stepIndex,
        uint256 amountRatio,
        bytes32 strategyId,
        address userAddress,
        bytes calldata
    )
        external
        payable
        override
        onlyEngine
        returns (address, address[] memory, uint256[] memory, address, uint256, address[] memory, uint256[] memory)
    {
        if (actionType == IConnector.ActionType.SUPPLY) {
            return _deposit(assetsIn[0], assetOut, amountRatio, strategyId, userAddress);
        } else if (actionType == IConnector.ActionType.WITHDRAW) {
            return _withdrawToken(assetsIn, assetOut, strategyId, userAddress);
        }
        revert InvalidAction();
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

    function _deposit(address assetIn, address assetOut, uint256 amountRatio, bytes32 strategyId, address userAddress)
        internal
        returns (address, address[] memory, uint256[] memory, address, uint256, address[] memory, uint256[] memory)
    {
        uint256 assetInBalance = strategyModule.getUserTokenBalance(strategyId, userAddress, assetIn);
        require(assetInBalance > 0, "Not enough balance");
        uint256 amountToDeposit = (assetInBalance * amountRatio) / 10_000;

        // transfer token from Strategy Module
        require(strategyModule.transferToken(assetIn, amountToDeposit), "Not enough token");

        // verify asset out before approving
        require(engine.verifyAssetOut(assetOut), "incorrect spender");

        // approve and deposit asset
        ERC20(assetIn).approve(assetOut, amountToDeposit);

        uint256 shareAmount = MorphInterface(assetOut).deposit(amountToDeposit, address(this));
        if (shareAmount == 0) revert();

        uint256[] memory assetsInAmount = new uint256[](1);
        assetsInAmount[0] = assetInBalance;

        address[] memory underlyingTokens = new address[](1);
        underlyingTokens[0] = assetIn;

        uint256[] memory underlyingAmounts = new uint256[](1);
        underlyingAmounts[0] = amountToDeposit;

        // transfer lp tokens to Strategy Module
        require(_transferToken(assetOut, shareAmount), "Invalid token amount");

        // update user token balance
        strategyModule.updateUserTokenBalance(strategyId, userAddress, assetOut, shareAmount, 0);
        strategyModule.updateUserTokenBalance(strategyId, userAddress, assetIn, amountToDeposit, 1);

        return (
            MORPHO_FACTORY, underlyingTokens, assetsInAmount, assetOut, shareAmount, underlyingTokens, underlyingAmounts
        );
    }

    function _withdrawToken(address[] memory assetsIn, address assetOut, bytes32 strategyId, address userAddress)
        internal
        returns (address, address[] memory, uint256[] memory, address, uint256, address[] memory, uint256[] memory)
    {
        // get share token balance
        uint256 stBalance = strategyModule.getUserTokenBalance(strategyId, userAddress, assetsIn[0]);

        // transfer share token from Strategy Module
        require(strategyModule.transferToken(assetsIn[0], stBalance), "Not enough share token");

        // redeem
        ERC20(assetsIn[0]).approve(assetsIn[0], stBalance);
        uint256 assetAmount = MorphInterface(assetsIn[0]).redeem(stBalance, address(strategyModule), address(this));
        // uint256 assetAmount = MorphInterface(assetsIn[0]).redeem(stBalance, address(this), address(this));
        if (assetAmount == 0) revert();

        // update user token balance
        strategyModule.updateUserTokenBalance(strategyId, userAddress, assetOut, assetAmount, 0);
        strategyModule.updateUserTokenBalance(strategyId, userAddress, assetsIn[0], stBalance, 1);

        return (
            MORPHO_FACTORY,
            new address[](0),
            new uint256[](0),
            assetOut,
            assetAmount,
            new address[](0),
            new uint256[](0)
        );
    }

    // Helper function
    function _transferToken(address _token, uint256 _amount) internal returns (bool) {
        return ERC20(_token).transfer(address(strategyModule), _amount);
    }
}
