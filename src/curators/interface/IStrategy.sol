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

    /**
     * @dev Create a strategy
     * @param _name descriptive, human-readable name for the strategy
     * @param _strategyDescription human-readable description for the strategy
     * @param _steps array representing the individual steps involved in the strategy
     * @param _minDeposit minimum amount of liquidity a user must provide to participate in the strategy
     * @param _maxTVL maximum total value of liquidity allowed in the strategy
     * @param _performanceFee fee charged on the strategy
     */
    function createStrategy(
        string memory _name,
        string memory _strategyDescription,
        Step[] memory _steps,
        uint256 _minDeposit,
        uint256 _maxTVL,
        uint256 _performanceFee
    ) external;

    /**
     * @dev Get strategy by strategy id
     * @param _strategyId strategy identity
     */
    function getStrategy(bytes32 _strategyId) external view returns (Strategy memory);

    /**
     * @dev Get all strategies for a curator
     * @param _curator address of the user that created the strategies
     */
    function getStrategy(address _curator) external view returns (Strategy[] memory);

    /**
     * @dev Get data on a particular strategy
     * @param _strategyId ID of a strategy
     */
    function getStrategyStats(bytes32 _strategyId) external view returns (StrategyStats memory);

    /**
     * @dev Get all strategies
     * @return allStrategies Array of all strategies
     */
    function getAllStrategies() external view returns (Strategy[] memory);

    /**
     * @dev Get total number of strategies
     * @return Total number of strategies
     */
    function getTotalStrategies() external view returns (uint256);

    /**
     * @dev Get all strategies that a user has participated in
     * @param _user address of the user to get strategies for
     * @return array of strategy IDs the user has participated in
     */
    function getUserStrategies(address _user) external view returns (bytes32[] memory);

    /**
     * @dev Get user's balance for a specific asset in a strategy
     * @param _strategyId ID of the strategy
     * @param _user Address of the user
     * @param _asset Address of the token to check balance for
     * @return AssetBalance struct containing token balance details
     */
    function getUserAssetBalance(bytes32 _strategyId, address _user, address _asset)
        external
        view
        returns (AssetBalance memory);

    /**
     * @dev Get user's share balance for a specific protocol and LP token in a strategy
     * @param _strategyId ID of the strategy
     * @param _user Address of the user
     * @param _protocol Address of the protocol (e.g. Aerodrome)
     * @param _lpToken Address of the LP token
     * @return ShareBalance struct containing share balance details
     */
    function getUserShareBalance(bytes32 _strategyId, address _user, address _protocol, address _lpToken)
        external
        view
        returns (ShareBalance memory);
}
