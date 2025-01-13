// SPDX-License-Identifier: GNU
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable2Step.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interface/IStrategy.sol";
import "./interface/IEngine.sol";

contract Strategy is Ownable2Step {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     STATE VARIABLES                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    IEngine engine;

    // curator => array of strategies
    mapping(address => ILiquidStrategy.Strategy[]) curatorStrategies;

    // strategy ID => strategies
    mapping(bytes32 => ILiquidStrategy.Strategy) strategies;

    // strategyId => stats
    mapping(bytes32 => ILiquidStrategy.StrategyStats) strategyStats;

    // strategyId => user => userStats
    mapping(bytes32 => mapping(address => ILiquidStrategy.UserStats)) userStats;

    // user => strategyIds
    mapping(address => bytes32[]) userStrategies;

    // strategyId => user => tokenAddress => balance
    mapping(bytes32 => mapping(address => mapping(address => uint256))) userTokenBalance;

    // strategyIds => user => bool
    mapping(bytes32 => mapping(address => bool)) hasJoinedStrategy;

    // connector => true/false
    mapping(address => bool) public approveConnector;

    // Array to keep track of all strategy IDs
    bytes32[] allStrategyIds;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          EVENTS                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @dev Emitted when a strategy is created
     * @param strategyId unique identifier for the strategy
     * @param curator address of the user creating the strategy
     * @param name descriptive, human-readable name for the strategy
     * @param strategyDescription human-readable description for the strategy
     * @param steps array representing the individual steps involved in the strategy
     * @param minDeposit minimum amount of liquidity a user must provide to participate in the strategy
     */
    event CreateStrategy(
        bytes32 indexed strategyId,
        address indexed curator,
        string name,
        string strategyDescription,
        ILiquidStrategy.Step[] steps,
        uint256 minDeposit
    );

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ERROR                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    error StrategyNotFound(bytes32 strategyId);
    error StrategyAlreadyExists(bytes32 strategyId);
    error Unauthorized(address caller);

    constructor(address _engine) Ownable(msg.sender) {
        engine = IEngine(_engine);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       MODIFIERS                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    modifier onlyConnector() {
        require(approveConnector[msg.sender], "caller is not a connector");
        _;
    }

    modifier onlyEngine() {
        require(msg.sender == address(engine), "caller is not the execution engine");
        _;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       PUBLIC FUNCTIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

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
        ILiquidStrategy.Step[] memory _steps,
        uint256 _minDeposit
    ) public {
        bytes32 strategyId = keccak256(abi.encodePacked(msg.sender, _name, _strategyDescription));
        // Check if strategy already exists
        if (strategies[strategyId].curator != address(0)) {
            revert StrategyAlreadyExists(strategyId);
        }

        ILiquidStrategy.Strategy memory _strategy = ILiquidStrategy.Strategy({
            strategyId: strategyId,
            curator: msg.sender,
            name: _name,
            strategyDescription: _strategyDescription,
            steps: _steps,
            minDeposit: _minDeposit
        });

        // Validate curator's strategy steps
        require(_validateSteps(_steps), "Invalid steps");

        // Store strategy in all relevant mappings
        strategies[strategyId] = _strategy;
        // Store curator's strategy
        curatorStrategies[msg.sender].push(_strategy);
        // Add to array of all strategy IDs
        allStrategyIds.push(strategyId);

        // Initialize strategy stats
        ILiquidStrategy.StrategyStats storage stats = strategyStats[strategyId];
        stats.lastUpdated = block.timestamp;

        emit CreateStrategy(strategyId, msg.sender, _name, _strategyDescription, _steps, _minDeposit);
    }

    function transferToken(address _token, uint256 _amount) public onlyConnector returns (bool) {
        // check if amount equals or more than available balance first
        // only connectors can call
        return IERC20(_token).transfer(msg.sender, _amount);
    }

    /**
     * @dev set value to true if a user joins a strategy, else, false
     * @param _strategyId  strategy identity
     * @param _user The address of the user
     */
    function setJoinedStrategy(bytes32 _strategyId, address _user, bool _status) public onlyEngine {
        hasJoinedStrategy[_strategyId][_user] = _status;
    }

    /**
     * @dev Update user stats
     */
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
    ) public onlyEngine {
        // Get user's stats
        ILiquidStrategy.UserStats storage _userStats = userStats[_strategyId][_userAddress];

        ILiquidStrategy.AssetBalance memory tempAssetBal =
            ILiquidStrategy.AssetBalance({assets: _assets, amounts: _assetsAmount});

        ILiquidStrategy.ShareBalance memory tempShareBal = ILiquidStrategy.ShareBalance({
            protocol: _protocol,
            shareToken: _shareToken,
            shareAmount: _shareAmount,
            underlyingTokens: _underlyingTokens,
            underlyingAmounts: _underlyingAmounts
        });

        //
        if (_userStats.tokenBalances.length == 0) {
            _userStats.joinTimestamp = block.timestamp;
        }

        if (_userStats.tokenBalances.length == stepIndex) {
            _userStats.tokenBalances.push(tempAssetBal);
            _userStats.shareBalances.push(tempShareBal);
        } else {
            ILiquidStrategy.AssetBalance memory userTokenBalances = _userStats.tokenBalances[stepIndex];
            ILiquidStrategy.ShareBalance memory userShareBalances = _userStats.shareBalances[stepIndex];

            for (uint256 i; i < userTokenBalances.assets.length; i++) {
                userTokenBalances.amounts[i] += _assetsAmount[i];
            }

            for (uint256 i; i < userShareBalances.underlyingTokens.length; i++) {
                userShareBalances.underlyingAmounts[i] += _underlyingAmounts[i];
            }

            userShareBalances.shareAmount += _shareAmount;

            _userStats.tokenBalances[stepIndex] = userTokenBalances;
            _userStats.shareBalances[stepIndex] = userShareBalances;
        }

        _userStats.lastActionTimestamp = block.timestamp;
    }

    /**
     * @dev Update strategy stats
     * @param _strategyId unique identifier of the strategy to update.
     * @param _assets list of asset addresses associated with the deposits.
     * @param _amounts corresponding amounts of each asset being deposited.
     * @param _performanceFee the performance fee generated by the strategy.
     * @param _indicator .
     */
    function updateStrategyStats(
        bytes32 _strategyId,
        address[] memory _assets,
        uint256[] memory _amounts,
        address _user,
        uint256 _performanceFee,
        uint256 _indicator
    ) public onlyEngine {
        ILiquidStrategy.StrategyStats storage stats = strategyStats[_strategyId];

        if (_indicator == 0) {
            for (uint256 i; i < _amounts.length; i++) {
                stats.totalDeposits[_assets[i]] += _amounts[i];
            }

            if (!hasJoinedStrategy[_strategyId][_user]) {
                stats.totalUsers++;
            }
        } else {
            for (uint256 i; i < _amounts.length; i++) {
                stats.totalDeposits[_assets[i]] -= _amounts[i];
            }
            stats.totalUsers--;
        }

        stats.totalFeeGenerated += _performanceFee;
        stats.lastUpdated = block.timestamp;
    }

    /**
     * @dev Update user strategy
     * @param _strategyId unique identifier of the strategy to update.
     * @param _user address of the user whose strategy is being updated.
     * @param _indicator determines the operation:
     *                   0 to add a strategyId,
     *                   any other value to remove the strategyId.
     */
    function updateUserStrategy(bytes32 _strategyId, address _user, uint256 _indicator) public onlyEngine {
        if (_indicator == 0) {
            userStrategies[_user].push(_strategyId);
        } else {
            bytes32[] memory cachedStrategies = userStrategies[_user];
            uint256 len = cachedStrategies.length;

            for (uint256 i; i < len; i++) {
                if (cachedStrategies[i] == _strategyId) {
                    for (uint256 j = i; j < len - 1; j++) {
                        userStrategies[_user][j] = userStrategies[_user][j + 1];
                    }

                    userStrategies[_user].pop();
                }
            }
        }
    }

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
    ) public onlyConnector {
        if (_indicator == 0) {
            userTokenBalance[_strategyId][_user][_token] += _amount;
        } else {
            userTokenBalance[_strategyId][_user][_token] -= _amount;
        }
    }

    /**
     * @dev Toggles the approval status of a connector. If the connector is currently approved,
     * it will be revoked, and vice versa.
     * @param _connector The address of the connector to toggle.
     */
    function toggleConnector(address _connector) public onlyOwner {
        approveConnector[_connector] = !approveConnector[_connector];
    }

    /**
     * @dev Get strategy by strategy id
     * @param _strategyId strategy identity
     */
    function getStrategy(bytes32 _strategyId) public view returns (ILiquidStrategy.Strategy memory) {
        ILiquidStrategy.Strategy memory strategy = strategies[_strategyId];
        if (strategy.curator == address(0)) {
            revert StrategyNotFound(_strategyId);
        }
        return strategy;
    }

    /**
     * @dev Get all strategies for a curator
     * @param _curator address of the user that created the strategies
     */
    function getStrategy(address _curator) public view returns (ILiquidStrategy.Strategy[] memory) {
        return curatorStrategies[_curator];
    }

    /**
     * @dev Get all strategies
     * @return allStrategies Array of all strategies
     */
    function getAllStrategies() public view returns (ILiquidStrategy.Strategy[] memory) {
        uint256 length = allStrategyIds.length;
        ILiquidStrategy.Strategy[] memory allStrategies = new ILiquidStrategy.Strategy[](length);

        for (uint256 i = 0; i < length; i++) {
            allStrategies[i] = strategies[allStrategyIds[i]];
        }

        return allStrategies;
    }

    /**
     * @dev Get total number of strategies
     * @return Total number of strategies
     */
    function getTotalStrategies() public view returns (uint256) {
        return allStrategyIds.length;
    }

    /**
     * @dev Get strategy statistics
     * @param _strategyId id of the strategy
     * @param _assets array of token address
     */
    function getStrategyStats(bytes32 _strategyId, address[] memory _assets)
        public
        view
        returns (uint256[] memory totalDeposits, uint256 totalUsers, uint256 totalFeeGenerated, uint256 lastUpdated)
    {
        ILiquidStrategy.StrategyStats storage stats = strategyStats[_strategyId];

        totalDeposits = new uint256[](_assets.length);

        for (uint256 i; i < _assets.length; i++) {
            totalDeposits[i] = stats.totalDeposits[_assets[i]];
        }
        totalUsers = stats.totalUsers;
        totalFeeGenerated = stats.totalFeeGenerated;
        lastUpdated = stats.lastUpdated;
    }

    /**
     * @dev Get all strategies that a user has participated in
     * @param _user address of the user to get strategies for
     * @return array of strategy IDs the user has participated in
     */
    function getUserStrategies(address _user) public view returns (bytes32[] memory) {
        return userStrategies[_user];
    }

    /**
     * @dev Get user's strategy statistics
     * @param _strategyId id of the strategy
     * @param _user address of the user to get strategies for
     */
    function getUserStrategyStats(bytes32 _strategyId, address _user)
        public
        view
        returns (ILiquidStrategy.UserStats memory)
    {
        return userStats[_strategyId][_user];
    }

    /**
     * @dev Get user's balance for a specific asset in a strategy
     * @param _strategyId ID of the strategy
     * @param _user Address of the user
     * @param _assets Address of the token to check balance for
     * @param _stepIndex Index of a step
     * @return AssetBalance struct containing token balance details
     */
    function getUserAssetBalance(bytes32 _strategyId, address _user, address[] memory _assets, uint256 _stepIndex)
        public
        view
        returns (ILiquidStrategy.AssetBalance memory)
    {
        ILiquidStrategy.UserStats memory stats = userStats[_strategyId][_user];
        for (uint256 i = 0; i < stats.tokenBalances.length; i++) {
            uint256 stepIndex = _stepIndex == type(uint256).max ? i : _stepIndex;

            if (
                keccak256(abi.encode(stats.tokenBalances[i].assets)) == keccak256(abi.encode(_assets)) && i == stepIndex
            ) {
                return stats.tokenBalances[i];
            }
        }
        return ILiquidStrategy.AssetBalance(_assets, new uint256[](0));
    }

    /**
     * @dev Get user's share balance for a specific protocol and Share token in a strategy
     * @param _strategyId ID of the strategy
     * @param _user Address of the user
     * @param _protocol Address of the protocol (e.g. Aerodrome)
     * @param _shareToken Address of the Share token
     * @param _stepIndex Index of a step
     * @return ShareBalance struct containing share balance details
     */
    function getUserShareBalance(
        bytes32 _strategyId,
        address _user,
        address _protocol,
        address _shareToken,
        uint256 _stepIndex
    ) public view returns (ILiquidStrategy.ShareBalance memory) {
        ILiquidStrategy.UserStats memory stats = userStats[_strategyId][_user];
        for (uint256 i = 0; i < stats.shareBalances.length; i++) {
            uint256 stepIndex = _stepIndex == type(uint256).max ? i : _stepIndex;
            if (
                stats.shareBalances[i].protocol == _protocol && stats.shareBalances[i].shareToken == _shareToken
                    && i == stepIndex
            ) {
                return stats.shareBalances[i];
            }
        }
        return ILiquidStrategy.ShareBalance(_protocol, _shareToken, 0, new address[](0), new uint256[](0));
    }

    /**
     * @dev Get user's token balance in a strategy
     * @param _strategyId ID of the strategy
     * @param _user Address of the user
     * @param _token Address of the token (e.g. USDC)
     * @return TokenBalance containing the user's token balance
     */
    function getUserTokenBalance(bytes32 _strategyId, address _user, address _token) public view returns (uint256) {
        return userTokenBalance[_strategyId][_user][_token];
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     INTERNAL FUNCTIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @dev Validate each step in the strategy
     * @param steps array representing the individual steps involved in the strategy
     */
    function _validateSteps(ILiquidStrategy.Step[] memory steps) internal view returns (bool) {
        for (uint256 i = 0; i < steps.length; i++) {
            // Validate connector address
            require(steps[i].connector != address(0), "Invalid connector address");

            // Validate assets
            for (uint256 j; j < steps[i].assetsIn.length; j++) {
                require(steps[i].assetsIn[j] != address(0), "Invalid input asset");
            }
            if (steps[i].actionType != IConnector.ActionType.SUPPLY) {
                require(steps[i].assetOut != address(0), "Invalid output asset");
            }

            // Validate amount ratio
            require(steps[i].amountRatio > 0 && steps[i].amountRatio <= 10_000, "Invalid amount ratio"); // Max 100%

            // Validate connector supports action
            IConnector connector = IConnector(steps[i].connector);
            require(
                _isValidActionForConnector(connector.getConnectorType(), steps[i].actionType),
                "Invalid action for connector type"
            );
        }

        return true;
    }

    /**
     * @dev Validates if an action is valid for a connector type
     * @param connectorType Type of connector
     * @param actionType Type of action
     */
    function _isValidActionForConnector(IConnector.ConnectorType connectorType, IConnector.ActionType actionType)
        internal
        pure
        returns (bool)
    {
        if (connectorType == IConnector.ConnectorType.LENDING) {
            return actionType == IConnector.ActionType.SUPPLY || actionType == IConnector.ActionType.WITHDRAW
                || actionType == IConnector.ActionType.BORROW || actionType == IConnector.ActionType.REPAY;
        } else if (connectorType == IConnector.ConnectorType.DEX) {
            return actionType == IConnector.ActionType.SWAP;
        } else if (connectorType == IConnector.ConnectorType.YIELD) {
            return actionType == IConnector.ActionType.STAKE || actionType == IConnector.ActionType.UNSTAKE
                || actionType == IConnector.ActionType.CLAIM;
        }

        return false;
    }
}
