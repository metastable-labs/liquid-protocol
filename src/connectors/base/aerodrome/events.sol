// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

contract AerodromeEvents {
    // Event emitted when liquidity is added to a pool
    event LiquidityAdded(
        address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB, uint256 liquidity
    );

    // Event emitted when liquidity is removed from a pool
    event LiquidityRemoved(
        address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB, uint256 liquidity
    );
}