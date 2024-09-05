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
    address internal constant UNISWAP_V2_ROUTER = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
    address internal constant UNISWAP_V2_FACTORY = 0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6;
}
