// SPDX-License-Identifier: GNU
pragma solidity ^0.8.20;

import "./interface/IStrategy.sol";

contract Strategy {
    // curator => array of strategies
    mapping(address => ILiquidStrategy.Strategy[]) curatorStrategies;

    /**
     * @dev Emitted when a strategy is created
     * @param strategyId unique identifier for the strategy
     * @param curator address of the user creating the strategy
     * @param name descriptive, human-readable name for the strategy
     * @param steps array representing the individual steps involved in the strategy
     * @param minDeposit minimum amount of liquidity a user must provide to participate in the strategy
     * @param maxTVL maximum total value of liquidity allowed in the strategy
     * @param performanceFee fee charged on the strategy
     */
    event CreateStrategy(
        bytes32 indexed strategyId,
        address indexed curator,
        string indexed name,
        ILiquidStrategy.Step[] steps,
        uint256 minDeposit,
        uint256 maxTVL,
        uint256 performanceFee
    );

    /**
     * @dev Create a strategy
     * @param _name descriptive, human-readable name for the strategy
     * @param _steps rray representing the individual steps involved in the strategy
     * @param _minDeposit minimum amount of liquidity a user must provide to participate in the strategy
     * @param _maxTVL maximum total value of liquidity allowed in the strategy
     * @param _performanceFee fee charged on the strategy
     */
    function createStrategy(
        string memory _name, // use solady string lib later
        ILiquidStrategy.Step[] memory _steps,
        uint256 _minDeposit,
        uint256 _maxTVL,
        uint256 _performanceFee
    ) public {
        bytes32 _strategyId = keccak256(abi.encodePacked(msg.sender, _name));
        ILiquidStrategy.Strategy memory _strategy = ILiquidStrategy.Strategy({
            strategyId: _strategyId,
            curator: msg.sender,
            name: _name,
            steps: _steps,
            minDeposit: _minDeposit,
            maxTVL: _maxTVL,
            performanceFee: _performanceFee
        });

        curatorStrategies[msg.sender].push(_strategy);

        emit CreateStrategy(_strategyId, msg.sender, _name, _steps, _minDeposit, _maxTVL, _performanceFee);
    }

    // function getStrategy(address _curator) public view returns (ILiquidStrategy.Strategy[] memory) {
    //     return curatorStrategies[_curator];
    // }
}
