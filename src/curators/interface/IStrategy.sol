pragma solidity ^0.8.20;

import "../../interface/IConnector.sol";

interface ILiquidStrategy is IConnector {
    struct Step {
        address connector; // Target connector
        ActionType actionType; // Action to perform
        address[] assetsIn; // Input asset(s)
        address assetOut; // Output asset
        uint256 amountRatio; // Amount as % of previous step
        bytes data; // Additional parameters
    }

    struct Strategy {
        bytes32 strategyId; // Strategy id
        address curator; // Strategy creator
        string name; // Strategy name
        string strategyDescription; // Strategy description
        Step[] steps; // Execution steps
        uint256 minDeposit; // Minimum deposit
        uint256 maxTVL; // Maximum TVL
        uint256 performanceFee; // Curator fee (basis points)
    }

    struct StrategyStats {
        uint256 totalDeposits; // Total amount deposited (total tvl)
        uint256 totalUsers; // Total unique users
        uint256 totalFeeGenerated; // Total fees generated
        uint256 lastUpdated; // Last stats update timestamp
    }

    struct AssetBalance {
        address asset; // Token address
        uint256 amount; // Raw token amount
        uint256 usdValue; // USD value at last update
        uint256 lastUpdated; // Last balance update timestamp
    }

    struct ShareBalance {
        address protocol; // Protocol address (e.g., Aerodrome)
        address lpToken; // LP token address
        uint256 lpAmount; // Amount of LP tokens
        address[] underlyingTokens; // Underlying token addresses
        uint256[] underlyingAmounts; // Amounts of underlying tokens
        uint256 lastUpdated; // Last balance update timestamp
    }

    struct UserStats {
        // Basic stats
        uint256 initialDeposit; // User's initial deposit in USD
        uint256 totalDepositedUSD; // Total amount deposited in USD
        uint256 totalWithdrawnUSD; // Total amount withdrawn in USD
        uint256 totalReward; // Total Reward generated in USD
        uint256 feesPaid; // Total fees paid in USD
        uint256 joinTimestamp; // When user joined
        uint256 lastActionTimestamp; // Last action timestamp
        // Detailed balance tracking
        AssetBalance[] tokenBalances; // Individual token balances
        ShareBalance[] shareBalances; // Protocol-specific share balances (LP tokens etc)
    }
}
