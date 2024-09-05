// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/// @title Constants
/// @notice Abstract contract containing constant addresses for common DeFi protocols and tokens
/// @dev Inherit from this contract to access these addresses in your contracts
abstract contract Constants {
    // Ethereum
    address internal constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // Wrapped Ether
    address internal constant WETH_ADDRESS = 0x4200000000000000000000000000000000000006;

    // Uniswap V2
    address internal constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address internal constant UNISWAP_V2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
}
