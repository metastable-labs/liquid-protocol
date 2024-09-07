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

    // aerodrome
    address internal constant AERODROME_ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address internal constant AERODROME_FACTORY = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;

    /// @dev Liquidity slippage tolerance: 0.5%
    // 10% for testing
    uint256 internal constant LIQ_SLIPPAGE = 1000;
    /// @dev 10 ** 18
    uint256 internal constant WAD = 1e18;
    /// @dev 10 ** 27
    uint256 internal constant RAY = 1e27;
}
