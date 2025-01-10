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
    }

    struct StrategyStats {
        address[] depositTokens; // Array of tokens that have been deposited
        uint256[] depositAmounts; // Array of corresponding deposit amounts
        uint256 totalUsers; // Total unique users
        uint256 totalFeeGenerated; // Total fees generated
        uint256 lastUpdated; // Last stats update timestamp
    }

    struct AssetBalance {
        address[] assets; // Token address
        uint256[] amounts; // Raw token amount
    }

    struct ShareBalance {
        address protocol; // Protocol address (e.g., Aerodrome)
        address shareToken; // Share token address
        uint256 shareAmount; // Amount of Share tokens
        address[] underlyingTokens; // Underlying token addresses
        uint256[] underlyingAmounts; // Amounts of underlying tokens
    }

    struct UserStats {
        // Basic stats
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
     */
    function createStrategy(
        string memory _name,
        string memory _strategyDescription,
        Step[] memory _steps,
        uint256 _minDeposit
    ) external;

    function transferToken(address _token, uint256 _amount) external returns (bool);

    function updateUserStats(
        bytes32 _strategyId,
        address _userAddress,
        address _protocol,
        address[] memory _assets,
        uint256[] memory _assetsAmount,
        address _shareToken,
        uint256 _shareAmount,
        address[] memory _underlyingTokens,
        uint256[] memory _underlyingAmounts,
        uint256 stepIndex
    ) external;

    function updateStrategyStats(
        bytes32 strategyId,
        address[] memory assetIn,
        uint256[] memory amounts,
        uint256 performanceFee
    ) external;

    function updateUserStrategy(bytes32 _strategyId, address _user, uint256 _indicator) external;

    /**
     * @dev Update user token balance
     * @param _strategyId unique identifier of the strategy.
     * @param _user address of the user whose balance is being updated.
     * @param _token address of the token.
     * @param _amount the amount of token to add or sub.
     * @param _indicator determines the operation:
     *                   0 to add,
     *                   any other value to sub.
     */
    function updateUserTokenBalance(
        bytes32 _strategyId,
        address _user,
        address _token,
        uint256 _amount,
        uint256 _indicator
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
     * @param _assets Address of the token to check balance for
     * @param _stepIndex Index of a step
     * @return AssetBalance struct containing token balance details
     */
    function getUserAssetBalance(bytes32 _strategyId, address _user, address[] memory _assets, uint256 _stepIndex)
        external
        view
        returns (AssetBalance memory);

    /**
     * @dev Get user's share balance for a specific protocol and LP token in a strategy
     * @param _strategyId ID of the strategy
     * @param _user Address of the user
     * @param _protocol Address of the protocol (e.g. Aerodrome)
     * @param _shareToken Address of the LP token
     * @param _stepIndex Index of a step
     * @return ShareBalance struct containing share balance details
     */
    function getUserShareBalance(
        bytes32 _strategyId,
        address _user,
        address _protocol,
        address _shareToken,
        uint256 _stepIndex
    ) external view returns (ShareBalance memory);

    /**
     * @dev Get user's token balance in a strategy
     * @param _strategyId ID of the strategy
     * @param _user Address of the user
     * @param _token Address of the token (e.g. USDC)
     * @return TokenBalance the user's token balance
     */
    function getUserTokenBalance(bytes32 _strategyId, address _user, address _token) external returns (uint256);
}
