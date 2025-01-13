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

    // Tokens
    address internal constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address internal constant DAI = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;
    address internal constant ETH = 0x4200000000000000000000000000000000000006;
    address internal constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    // Oracle
    address internal constant ORACLE = 0x333Cd307bd0d8fDB3c38b14eacC4072FF548176B;
    address internal constant ENGINE = 0xe7D11A96aB3813D8232a0711D4fa4f60E2f50B19;

    // Moonwell Basic contracts
    address internal constant COMPTROLLER = 0xfBb21d0380beE3312B33c4353c8936a0F13EF26C;
    address internal constant MW_WETH_UNWRAPPER = 0x1382cFf3CeE10D283DccA55A30496187759e4cAf;
    address internal constant MOONWELL_USDC = 0xEdc817A28E8B93B03976FBd4a3dDBc9f7D176c22;
    address internal constant MOONWELL_CBBTC = 0xF877ACaFA28c19b96727966690b2f44d35aD5976;
    address internal constant MOONWELL_WETH = 0x628ff693426583D9a7FB391E54366292F509D457;
    address internal constant MOONWELL_DAI = 0x73b06D8d18De422E269645eaCe15400DE7462417;
    address internal constant MOONWELL_EURC = 0xb682c840B5F4FC58B20769E691A6fa1305A501a2;

    // MetaMorpho contracts
    address internal constant MORPHO_FACTORY = 0xA9c3D3a366466Fa809d1Ae982Fb2c46E5fC41101;

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
