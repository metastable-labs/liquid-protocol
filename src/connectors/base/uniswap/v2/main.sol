// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "./BaseConnector.sol";
import "./UniswapV2Utils.sol";
import "./interface/IUniswapV2Router02.sol";
import "./interface/IUniswapV2Factory.sol";
import "./UniswapV2Events.sol";

/// @title UniswapV2Connector
/// @notice A connector for interacting with Uniswap V2 protocol
/// @dev This contract allows adding and removing liquidity on Uniswap V2
contract UniswapV2Connector is BaseConnector, UniswapV2Events {
    using UniswapV2Utils for *;

    IUniswapV2Router02 public immutable router;
    IUniswapV2Factory public immutable factory;
    address public immutable WETH;

    // Custom errors
    error InvalidSelector();
    error ETHTransferFailed();
    error InsufficientLiquidity();
    error DeadlineExpired();
    error SlippageExceeded();

    /// @notice Initializes the UniswapV2Connector
    /// @param _weth Address of the WETH contract
    /// @param _router Address of the Uniswap V2 Router
    /// @param _factory Address of the Uniswap V2 Factory
    /// @param name Name of the connector
    /// @param version Version of the connector
    constructor(address _weth, address _router, address _factory, string memory name, uint256 version)
        BaseConnector(name, version)
    {
        WETH = _weth;
        router = IUniswapV2Router02(_router);
        factory = IUniswapV2Factory(_factory);
    }

    /// @notice Executes a function call on the Uniswap V2 protocol
    /// @param data The calldata for the function call
    /// @return bytes The return data from the function call
    function execute(bytes calldata data) external payable override returns (bytes memory) {
        bytes4 selector = data.getSelector();

        if (selector == this.addLiquidity.selector) {
            (
                address tokenA,
                address tokenB,
                uint256 amountADesired,
                uint256 amountBDesired,
                uint256 amountAMin,
                uint256 amountBMin,
                uint256 deadline
            ) = abi.decode(data[4:], (address, address, uint256, uint256, uint256, uint256, uint256));
            return abi.encode(
                _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin, deadline)
            );
        } else if (selector == this.addLiquidityETH.selector) {
            (address token, uint256 amountTokenDesired, uint256 amountTokenMin, uint256 amountETHMin, uint256 deadline)
            = abi.decode(data[4:], (address, uint256, uint256, uint256, uint256));
            return abi.encode(_addLiquidityETH(token, amountTokenDesired, amountTokenMin, amountETHMin, deadline));
        } else if (selector == this.removeLiquidity.selector) {
            (
                address tokenA,
                address tokenB,
                uint256 liquidity,
                uint256 amountAMin,
                uint256 amountBMin,
                uint256 deadline
            ) = abi.decode(data[4:], (address, address, uint256, uint256, uint256, uint256));
            return abi.encode(_removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, deadline));
        } else if (selector == this.removeLiquidityETH.selector) {
            (address token, uint256 liquidity, uint256 amountTokenMin, uint256 amountETHMin, uint256 deadline) =
                abi.decode(data[4:], (address, uint256, uint256, uint256, uint256));
            return abi.encode(_removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, deadline));
        }

        revert InvalidSelector();
    }

    /// @notice Adds liquidity to a ERC20⇄ERC20 pool
    /// @param tokenA The contract address of the first token
    /// @param tokenB The contract address of the second token
    /// @param amountADesired The amount of tokenA to add as liquidity
    /// @param amountBDesired The amount of tokenB to add as liquidity
    /// @param amountAMin Bounds the extent to which the B/A price can go up before the transaction reverts
    /// @param amountBMin Bounds the extent to which the A/B price can go up before the transaction reverts
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @return amountA The amount of tokenA sent to the pool
    /// @return amountB The amount of tokenB sent to the pool
    /// @return liquidity The amount of liquidity tokens minted
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        uint256 deadline
    ) internal returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        if (block.timestamp > deadline) revert DeadlineExpired();

        (amountA, amountB, liquidity) = router.addLiquidity(
            tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin, msg.sender, deadline
        );

        if (liquidity == 0) revert InsufficientLiquidity();

        emit LiquidityAdded(tokenA, tokenB, amountA, amountB, liquidity);
    }

    /// @notice Adds liquidity to a ERC20⇄WETH pool with ETH
    /// @param token The contract address of the token
    /// @param amountTokenDesired The amount of token to add as liquidity
    /// @param amountTokenMin Bounds the extent to which the WETH/token price can go up before the transaction reverts
    /// @param amountETHMin Bounds the extent to which the token/WETH price can go up before the transaction reverts
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @return amountToken The amount of token sent to the pool
    /// @return amountETH The amount of ETH converted to WETH and sent to the pool
    /// @return liquidity The amount of liquidity tokens minted
    function _addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        uint256 deadline
    ) internal returns (uint256 amountToken, uint256 amountETH, uint256 liquidity) {
        if (block.timestamp > deadline) revert DeadlineExpired();

        (amountToken, amountETH, liquidity) = router.addLiquidityETH{value: msg.value}(
            token, amountTokenDesired, amountTokenMin, amountETHMin, msg.sender, deadline
        );

        if (liquidity == 0) revert InsufficientLiquidity();

        // Refund excess ETH to the smart wallet
        if (amountETH < msg.value) {
            (bool success,) = msg.sender.call{value: msg.value - amountETH}("");
            if (!success) revert ETHTransferFailed();
        }

        emit LiquidityAddedETH(token, amountToken, amountETH, liquidity);
    }

    /// @notice Removes liquidity from a ERC20⇄ERC20 pool
    /// @param tokenA The contract address of the first token
    /// @param tokenB The contract address of the second token
    /// @param liquidity The amount of liquidity tokens to burn
    /// @param amountAMin The minimum amount of tokenA that must be received for the transaction not to revert
    /// @param amountBMin The minimum amount of tokenB that must be received for the transaction not to revert
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @return amountA The amount of tokenA received
    /// @return amountB The amount of tokenB received
    function _removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        uint256 deadline
    ) internal returns (uint256 amountA, uint256 amountB) {
        if (block.timestamp > deadline) revert DeadlineExpired();

        (amountA, amountB) =
            router.removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, msg.sender, deadline);

        if (amountA < amountAMin || amountB < amountBMin) {
            revert SlippageExceeded();
        }

        emit LiquidityRemoved(tokenA, tokenB, amountA, amountB, liquidity);
    }

    /// @notice Removes liquidity from a ERC20⇄WETH pool and receives ETH
    /// @param token The contract address of the token
    /// @param liquidity The amount of liquidity tokens to burn
    /// @param amountTokenMin The minimum amount of token that must be received for the transaction not to revert
    /// @param amountETHMin The minimum amount of ETH that must be received for the transaction not to revert
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @return amountToken The amount of token received
    /// @return amountETH The amount of ETH received
    function _removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        uint256 deadline
    ) internal returns (uint256 amountToken, uint256 amountETH) {
        if (block.timestamp > deadline) revert DeadlineExpired();

        (amountToken, amountETH) =
            router.removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, msg.sender, deadline);

        if (amountToken < amountTokenMin || amountETH < amountETHMin) {
            revert SlippageExceeded();
        }

        emit LiquidityRemovedETH(token, amountToken, amountETH, liquidity);
    }
}
