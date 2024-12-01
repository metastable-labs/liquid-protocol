pragma solidity ^0.8.20;

import "../../interface/IProtocol.sol";

interface ILiquidStrategy is IProtocolIntegration {
    struct Step {
        address protocol; // Target protocol
        ActionType actionType; // Action to perform
        address assetIn; // Input asset
        address assetOut; // Output asset
        uint256 amountRatio; // Amount as % of previous step
        bytes data; // Additional parameters
    }

    struct Strategy {
        address curator; // Strategy creator
        string name; // Strategy name
        Step[] steps; // Execution steps
        uint256 minDeposit; // Minimum deposit
        uint256 maxTVL; // Maximum TVL
        uint256 performanceFee; // Curator fee (basis points)
    }
}
