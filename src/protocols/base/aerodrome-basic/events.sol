// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/**
 * @title AerodromeEvents
 * @dev Contract that defines events for tracking liquidity operations, swaps, staking,
 * and reward claiming in the Aerodrome protocol. These events enable efficient off-chain
 * tracking of protocol activities.
 */
contract AerodromeEvents {
    /**
     * @dev Emitted when liquidity is added to a trading pool
     * @param tokenA Address of the first token in the pair
     * @param tokenB Address of the second token in the pair
     * @param amountA Amount of tokenA added to the pool
     * @param amountB Amount of tokenB added to the pool
     * @param liquidity Amount of LP tokens minted to represent the added liquidity
     */
    event LiquidityAdded(
        address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB, uint256 liquidity
    );

    /**
     * @dev Emitted when liquidity is removed from a trading pool
     * @param tokenA Address of the first token in the pair
     * @param tokenB Address of the second token in the pair
     * @param amountA Amount of tokenA removed from the pool
     * @param amountB Amount of tokenB removed from the pool
     * @param liquidity Amount of LP tokens burned during the removal
     */
    event LiquidityRemoved(
        address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB, uint256 liquidity
    );

    /**
     * @dev Emitted when a token swap occurs in a pool
     * @param tokenIn Address of the token being swapped in
     * @param tokenOut Address of the token being received
     * @param amountIn Amount of input tokens swapped
     * @param amountOut Amount of output tokens received
     */
    event Swapped(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);

    /**
     * @dev Emitted when LP tokens are staked in a gauge for earning rewards
     * @param guageAddress Address of the gauge where tokens are staked
     * @param amount Amount of LP tokens staked
     */
    event LPTokenStaked(address indexed guageAddress, uint256 amount);

    /**
     * @dev Emitted when LP tokens are unstaked from a gauge
     * @param guageAddress Address of the gauge from where tokens are unstaked
     * @param amount Amount of LP tokens unstaked
     * @param recepient Address receiving the unstaked LP tokens
     */
    event LPTokenUnStaked(address indexed guageAddress, uint256 amount, address indexed recepient);

    /**
     * @dev Emitted when AERO rewards are claimed from a gauge
     * @param guageAddress Address of the gauge from which rewards are claimed
     * @param rewardToken Address of the reward token being claimed
     */
    event AeroRewardsClaimed(address indexed guageAddress, address indexed rewardToken);

    /**
     * @dev Emitted when trading fees are withdrawn from a pool
     * @param poolAddress Address of the pool from which fees are withdrawn
     * @param token0 Address of the first token in the pair
     * @param amount0 Amount of token0 fees withdrawn
     * @param token1 Address of the second token in the pair
     * @param amount1 Amount of token1 fees withdrawn
     */
    event FeesWithdrawn(address indexed poolAddress, address token0, uint256 amount0, address token1, uint256 amount1);
}
