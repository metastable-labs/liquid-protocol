// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/// @title Constants
/// @notice Abstract contract containing constant addresses for common DeFi protocols and tokens
/// @dev Inherit from this contract to access these addresses in your contracts
abstract contract Constants {
    // Ethereum
    address internal constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // Wrapped Ether
    address internal constant WETH = 0x4200000000000000000000000000000000000006;

    // ChainLink Price Feeds contract
    address internal constant SEQUENCER_UPTIME_FEED = 0xBCF85224fc0756B9Fa45aA7892530B47e10b6433; // base mainnet
    address internal constant CBBTC_USD = 0x07DA0E54543a844a80ABE69c8A12F22B3aA59f9D;
    address internal constant DAI_USD = 0x591e79239a7d679378eC8c847e5038150364C78F;
    address internal constant ETH_USD = 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70;
    address internal constant USDC_USD = 0x7e860098F58bBFC8648a4311b374B1D669a2bc6B;

    // Aerodrome Basic contracts
    address internal constant AERODROME_ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address internal constant AERODROME_FACTORY = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;

    /// @dev Liquidity slippage tolerance: 0.5%
    // 3% for testing
    // 10000 = 100%, 5000 = 50%, 100 = 1%, 1 = 0.01%
    uint256 internal constant LIQ_SLIPPAGE = 300;
    /// @dev 10 ** 18
    uint256 internal constant WAD = 1e18;
    /// @dev 10 ** 27
    uint256 internal constant RAY = 1e27;
}
