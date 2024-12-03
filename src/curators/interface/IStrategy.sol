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
}
