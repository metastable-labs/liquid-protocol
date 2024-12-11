// SPDX-License-Identifier: GNU
pragma solidity ^0.8.20;

import "./interface/IStrategy.sol";
import {ERC4626, ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

contract Engine is ERC4626 {
    // might change later
    ILiquidStrategy strategyModule;

    constructor(address _strategyModule) ERC4626(IERC20(address(this))) ERC20("LIQUID", "LLP") {
        strategyModule = ILiquidStrategy(_strategyModule);
    }

    function join(bytes32 _strategyId, uint256[] memory amounts) public {
        // Fetch the strategy
        ILiquidStrategy.Strategy memory _strategy = strategyModule.getStrategy(_strategyId);

        // Validate strategy - not necessary single we validate the steps before strategy creation

        // Transfer initial deposit(s) from caller
        uint256 initialAssetsInLength = _strategy.steps[0].assetsIn.length;

        for (uint256 i; i < initialAssetsInLength; i++) {
            address asset = _strategy.steps[0].assetsIn[i];
            // approve `this` as spender in client first
            ERC4626(asset).transferFrom(msg.sender, address(this), amounts[i]);
            // tranfer token to connector
            ERC4626(asset).transfer(_strategy.steps[0].connector, amounts[i]);
        }

        uint256 prevLoopAmountOut;
        // Execute all steps atomically
        for (uint256 i; i < _strategy.steps.length; i++) {
            // Fetch step
            ILiquidStrategy.Step memory _step = _strategy.steps[i];

            // Default ratio to 100% for first step
            uint256 _amountRatio = i == 0 ? 10_000 : _step.amountRatio;

            // Constrain the first step to certain actions
            if (
                i == 0
                    && (
                        (_step.actionType == IConnector.ActionType.BORROW)
                            || (_step.actionType == IConnector.ActionType.UNSTAKE)
                            || (_step.actionType == IConnector.ActionType.WITHDRAW)
                            || (_step.actionType == IConnector.ActionType.REPAY)
                    )
            ) revert();

            // Execute connector action
            try IConnector(_step.connector).execute(
                _step.actionType,
                _step.assetsIn,
                amounts,
                _step.assetOut,
                _amountRatio,
                prevLoopAmountOut,
                _strategyId,
                msg.sender,
                _step.data
            ) returns (uint256 amountOut) {
                // Verify result
                // require(verifyResult(amountOut, _step.assetOut, _step.connector), "Invalid result");

                prevLoopAmountOut = amountOut;

                // Update the strategy module
            } catch Error(string memory reason) {
                revert(string(abi.encodePacked("Step ", i, " failed: ", reason)));
            }
        }

        // zero free for now
        uint256 _fee = 0;

        // update strategy stats
        strategyModule.updateStrategyStats(_strategyId, amounts, _fee);

        // After the steps, send lptoken(s) to strategy module
        // and update user and strategy stats
    }

    function verifyResult(uint256 _amountOut, address _assetOut, address _connector) internal view returns (bool) {
        // return ERC4626(_assetOut).balanceOf(address(this)) == _amountOut;
        return ERC4626(_assetOut).balanceOf(_connector) == _amountOut;
    }
}
