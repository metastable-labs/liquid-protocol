// SPDX-License-Identifier: GNU
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {Strategy} from "../../src/curators/strategy.sol";
import {Engine} from "../../src/curators/engine.sol";
import {ILiquidStrategy} from "../../src/curators/interface/IStrategy.sol";
import {IConnector} from "../../src/interface/IConnector.sol";
import {MockToken} from "../mocks/Token.sol";
import {MockConnector} from "../mocks/Connector.sol";

contract StrategyStatsTest is Test {
    Strategy public strategy;
    Engine public engine;
    MockToken public token;
    MockConnector public connector;

    address public curator = address(1);
    address public user = address(2);
    bytes32 public strategyId;

    struct StepYield {
        uint256 baseYield; // Base lending/trading yield
        uint256 protocolFees; // Accumulated protocol fees
        uint256 incentives; // Program incentives
        uint256 totalYield; // Total estimated yield
    }

    function setUp() public {
        // Deploy contracts
        engine = new Engine();
        strategy = new Strategy(address(engine));
        token = new MockToken("Test Token", "TEST");
        connector = new MockConnector();

        // Setup connector
        strategy.toggleConnector(address(connector));

        // Create test strategy
        vm.startPrank(curator);
        address[] memory assetsIn = new address[](1);
        assetsIn[0] = address(token);

        ILiquidStrategy.Step[] memory steps = new ILiquidStrategy.Step[](1);
        steps[0] = ILiquidStrategy.Step({
            connector: address(connector),
            actionType: IConnector.ActionType.SUPPLY,
            assetsIn: assetsIn,
            assetOut: address(0),
            amountRatio: 10_000,
            data: ""
        });

        strategy.createStrategy(
            "Test Strategy",
            "Test Description",
            steps,
            100
        );
        vm.stopPrank();

        // Get strategy ID
        strategyId = keccak256(
            abi.encodePacked(curator, "Test Strategy", "Test Description")
        );
    }

    function test_UpdateStrategyStats() public {
        // Setup test data
        address[] memory assets = new address[](1);
        assets[0] = address(token);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000;
        uint256 performanceFee = 10;

        console2.log("=== Initial Strategy Creation ===");
        ILiquidStrategy.Strategy memory strat = strategy.getStrategy(
            strategyId
        );
        console2.log("Strategy Name:", strat.name);
        console2.log("Strategy Description:", strat.strategyDescription);
        console2.log("Curator:", strat.curator);
        console2.log("Min Deposit:", strat.minDeposit);
        console2.log("Number of Steps:", strat.steps.length);

        // Update stats
        vm.prank(address(engine));
        strategy.updateStrategyStats(
            strategyId,
            assets,
            amounts,
            performanceFee
        );

        // Get stats
        console2.log("\n=== After First Deposit ===");
        ILiquidStrategy.StrategyStats memory stats = strategy.getStrategyStats(
            strategyId
        );
        _logStats(stats);

        // Update stats again with same token
        amounts[0] = 500;
        vm.prank(address(engine));
        strategy.updateStrategyStats(
            strategyId,
            assets,
            amounts,
            performanceFee
        );

        // Get updated stats
        console2.log("\n=== After Second Deposit ===");
        stats = strategy.getStrategyStats(strategyId);
        _logStats(stats);

        // Verify stats are correct
        assertEq(stats.depositTokens.length, 1);
        assertEq(stats.depositAmounts[0], 1500); // 1000 + 500
        assertEq(stats.totalUsers, 2);
        assertEq(stats.totalFeeGenerated, 20); // 10 + 10
    }

    function _logStats(
        ILiquidStrategy.StrategyStats memory stats
    ) internal view {
        console2.log("Total Users:", stats.totalUsers);
        console2.log("Total Fee Generated:", stats.totalFeeGenerated);
        console2.log("Last Updated:", stats.lastUpdated);
        console2.log("Deposit Tokens:");
        for (uint256 i = 0; i < stats.depositTokens.length; i++) {
            console2.log("  Token", i, ":", stats.depositTokens[i]);
            console2.log("  Amount", i, ":", stats.depositAmounts[i]);
        }
    }

    function test_UpdateUserStats() public {
        // Setup test data
        address[] memory assets = new address[](1);
        assets[0] = address(token);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000;

        address[] memory underlyingTokens = new address[](1);
        underlyingTokens[0] = address(token);
        uint256[] memory underlyingAmounts = new uint256[](1);
        underlyingAmounts[0] = 900;

        console2.log("\n=== User Stats Test ===");
        console2.log("User Address:", user);
        console2.log("Initial Deposit Token:", address(token));
        console2.log("Initial Deposit Amount:", amounts[0]);
        console2.log("Underlying Token:", underlyingTokens[0]);
        console2.log("Underlying Amount:", underlyingAmounts[0]);

        // Update user stats for step 0
        vm.prank(address(engine));
        strategy.updateUserStats(
            strategyId,
            user,
            address(connector),
            assets,
            amounts,
            address(0),
            0,
            underlyingTokens,
            underlyingAmounts,
            0
        );

        // Get user stats
        ILiquidStrategy.UserStats memory userStats = strategy
            .getUserStrategyStats(strategyId, user);

        console2.log("\n=== User Stats After Update ===");
        _logUserStats(userStats);

        // Verify user stats
        assertEq(userStats.tokenBalances.length, 1);
        assertEq(userStats.tokenBalances[0].assets[0], address(token));
        assertEq(userStats.tokenBalances[0].amounts[0], 1000);
        assertEq(userStats.shareBalances[0].protocol, address(connector));
        assertEq(
            userStats.shareBalances[0].underlyingTokens[0],
            address(token)
        );
        assertEq(userStats.shareBalances[0].underlyingAmounts[0], 900);
        assertEq(userStats.joinTimestamp, block.timestamp);
        assertEq(userStats.lastActionTimestamp, block.timestamp);
    }

    function _logUserStats(
        ILiquidStrategy.UserStats memory stats
    ) internal view {
        console2.log("Join Timestamp:", stats.joinTimestamp);
        console2.log("Last Action Timestamp:", stats.lastActionTimestamp);

        console2.log("\nToken Balances:");
        for (uint256 i = 0; i < stats.tokenBalances.length; i++) {
            console2.log("Step", i, "Tokens:");
            for (uint256 j = 0; j < stats.tokenBalances[i].assets.length; j++) {
                console2.log("  Token:", stats.tokenBalances[i].assets[j]);
                console2.log("  Amount:", stats.tokenBalances[i].amounts[j]);
            }
        }

        console2.log("\nShare Balances:");
        for (uint256 i = 0; i < stats.shareBalances.length; i++) {
            console2.log("Step", i, "Shares:");
            console2.log("  Protocol:", stats.shareBalances[i].protocol);
            console2.log("  Share Token:", stats.shareBalances[i].shareToken);
            console2.log("  Share Amount:", stats.shareBalances[i].shareAmount);
            for (
                uint256 j = 0;
                j < stats.shareBalances[i].underlyingTokens.length;
                j++
            ) {
                console2.log(
                    "  Underlying Token:",
                    stats.shareBalances[i].underlyingTokens[j]
                );
                console2.log(
                    "  Underlying Amount:",
                    stats.shareBalances[i].underlyingAmounts[j]
                );
            }
        }

        console2.log("\nEstimated Yields per Step:");
        for (uint256 i = 0; i < stats.shareBalances.length; i++) {
            ILiquidStrategy.Step memory step = strategy
                .getStrategy(strategyId)
                .steps[i];
            StepYield memory yield = _calculateStepYield(
                step,
                stats.shareBalances[i],
                2 weeks // Current epoch duration
            );

            console2.log("Step", i, "Yields:");
            console2.log("  Base Yield:", yield.baseYield);
            console2.log("  Protocol Fees:", yield.protocolFees);
            console2.log("  Incentives:", yield.incentives);
            console2.log("  Total Estimated Yield:", yield.totalYield);
        }
    }

    function test_GetUserAssetBalance() public {
        // Setup and update user stats first
        address[] memory assets = new address[](1);
        assets[0] = address(token);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000;

        vm.prank(address(engine));
        strategy.updateUserStats(
            strategyId,
            user,
            address(connector),
            assets,
            amounts,
            address(0),
            0,
            new address[](0),
            new uint256[](0),
            0
        );

        // Get asset balance
        ILiquidStrategy.AssetBalance memory balance = strategy
            .getUserAssetBalance(strategyId, user, assets, 0);

        // Verify balance
        assertEq(balance.assets[0], address(token));
        assertEq(balance.amounts[0], 1000);
    }

    function test_UpdateUserStrategy() public {
        // Add strategy to user's list
        vm.prank(address(engine));
        strategy.updateUserStrategy(strategyId, user, 0);

        // Verify strategy was added
        bytes32[] memory userStrategies = strategy.getUserStrategies(user);
        assertEq(userStrategies.length, 1);
        assertEq(userStrategies[0], strategyId);

        // Remove strategy from user's list
        vm.prank(address(engine));
        strategy.updateUserStrategy(strategyId, user, 1);

        // Verify strategy was removed
        userStrategies = strategy.getUserStrategies(user);
        assertEq(userStrategies.length, 0);
    }

    function _calculateStepYield(
        ILiquidStrategy.Step memory step,
        ILiquidStrategy.ShareBalance memory balance,
        uint256 epochDuration
    ) internal pure returns (StepYield memory) {
        StepYield memory yield;

        // Example calculation (you would replace with actual protocol rates)
        if (step.actionType == IConnector.ActionType.SUPPLY) {
            // Base yield (example: 5% APY)
            yield.baseYield = (balance.shareAmount * 5) / 100;

            // Protocol fees (example: 0.1% of volume)
            yield.protocolFees = (balance.shareAmount * 1) / 1000;

            // Incentives (if any program exists)
            yield.incentives =
                (balance.shareAmount * epochDuration * 2) /
                (365 days * 100); // 2% APR
        }

        yield.totalYield =
            yield.baseYield +
            yield.protocolFees +
            yield.incentives;
        return yield;
    }
}
