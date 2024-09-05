// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "../../../../BaseConnector.sol";
import "../interface/IUniswapV2Router02.sol";
import "../interface/IUniswapV2Factory.sol";
import "./events.sol";
import "../../common/constant.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title UniswapV2Connector
/// @notice A connector for interacting with Uniswap V2 protocol
/// @dev This contract allows adding and removing liquidity on Uniswap V2
contract UniswapV2Connector is BaseConnector, Constants, UniswapV2Events {
    /// @notice Allows the contract to receive ETH
    receive() external payable {}

    /// @notice Fallback function to receive ETH
    fallback() external payable {}

    /// @notice The Uniswap V2 Router contract
    IUniswapV2Router02 public immutable router;

    /// @notice The Uniswap V2 Factory contract
    IUniswapV2Factory public immutable factory;

    /// @notice The address of the Wrapped Ether (WETH) contract
    address public immutable WETH;

    /// @notice Thrown when an invalid function selector is provided
    error InvalidSelector();

    /// @notice Thrown when an ETH transfer fails
    error ETHTransferFailed();

    /// @notice Thrown when insufficient liquidity is provided
    error InsufficientLiquidity();

    /// @notice Thrown when the transaction deadline has expired
    error DeadlineExpired();

    /// @notice Thrown when slippage tolerance is exceeded
    error SlippageExceeded();

    /// @notice Initializes the UniswapV2Connector
    /// @param name Name of the connector
    /// @param version Version of the connector
    constructor(string memory name, uint256 version) BaseConnector(name, version) {
        WETH = WETH_ADDRESS;
        router = IUniswapV2Router02(UNISWAP_V2_ROUTER);
        factory = IUniswapV2Factory(UNISWAP_V2_FACTORY);
    }

    /// @notice Executes a function call on the Uniswap V2 protocol
    /// @param data The calldata for the function call
    /// @return bytes The return data from the function call
    function execute(bytes calldata data) external payable override returns (bytes memory) {
        bytes4 selector = _getSelector(data);

        if (selector == router.addLiquidity.selector) {
            (uint256 amountA, uint256 amountB, uint256 liquidity) = _addLiquidity(data);
            return abi.encode(amountA, amountB, liquidity);
        } else if (selector == router.addLiquidityETH.selector) {
            (uint256 amountToken, uint256 amountETH, uint256 liquidity) = _addLiquidityETH(data);
            return abi.encode(amountToken, amountETH, liquidity);
        } else if (selector == router.removeLiquidity.selector) {
            (uint256 amountA, uint256 amountB) = _removeLiquidity(data);
            return abi.encode(amountA, amountB);
        } else if (selector == router.removeLiquidityETH.selector) {
            (uint256 amountToken, uint256 amountETH) = _removeLiquidityETH(data);
            return abi.encode(amountToken, amountETH);
        }

        revert InvalidSelector();
    }

    /// @notice Adds liquidity to a ERC20⇄ERC20 pool
    /// @param data The calldata containing function parameters
    /// @return amountA The amount of tokenA sent to the pool
    /// @return amountB The amount of tokenB sent to the pool
    /// @return liquidity The amount of liquidity tokens minted
    function _addLiquidity(bytes calldata data)
        internal
        returns (uint256 amountA, uint256 amountB, uint256 liquidity)
    {
        (
            ,
            ,
            address tokenA,
            address tokenB,
            uint256 amountADesired,
            uint256 amountBDesired,
            uint256 amountAMin,
            uint256 amountBMin,
            uint256 deadline
        ) = abi.decode(data[4:], (address, address, address, address, uint256, uint256, uint256, uint256, uint256));

        if (block.timestamp > deadline) revert DeadlineExpired();

        IERC20(tokenA).approve(address(router), amountADesired);
        IERC20(tokenB).approve(address(router), amountBDesired);

        (amountA, amountB, liquidity) = router.addLiquidity(
            tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin, msg.sender, deadline
        );

        if (liquidity == 0) revert InsufficientLiquidity();

        emit LiquidityAdded(tokenA, tokenB, amountA, amountB, liquidity);
    }

    /// @notice Adds liquidity to a ERC20⇄WETH pool with ETH
    /// @param data The calldata containing function parameters
    /// @return amountToken The amount of token sent to the pool
    /// @return amountETH The amount of ETH converted to WETH and sent to the pool
    /// @return liquidity The amount of liquidity tokens minted
    function _addLiquidityETH(bytes calldata data)
        internal
        returns (uint256 amountToken, uint256 amountETH, uint256 liquidity)
    {
        (,, address token, uint256 amountTokenDesired, uint256 amountTokenMin, uint256 amountETHMin, uint256 deadline) =
            abi.decode(data[4:], (address, address, address, uint256, uint256, uint256, uint256));

        if (block.timestamp > deadline) revert DeadlineExpired();

        IERC20(token).approve(address(router), amountTokenDesired);

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
    /// @param data The calldata containing function parameters
    /// @return amountA The amount of tokenA received
    /// @return amountB The amount of tokenB received
    function _removeLiquidity(bytes calldata data) internal returns (uint256 amountA, uint256 amountB) {
        (,, address tokenA, address tokenB, uint256 liquidity, uint256 amountAMin, uint256 amountBMin, uint256 deadline)
        = abi.decode(data[4:], (address, address, address, address, uint256, uint256, uint256, uint256));

        if (block.timestamp > deadline) revert DeadlineExpired();
        // Get the pair address
        address pair = factory.getPair(tokenA, tokenB);
        if (pair == address(0)) revert("Pair does not exist");

        // Approve the router to spend the liquidity tokens
        IERC20(pair).approve(address(router), liquidity);

        (amountA, amountB) =
            router.removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, msg.sender, deadline);

        if (amountA < amountAMin || amountB < amountBMin) {
            revert SlippageExceeded();
        }

        emit LiquidityRemoved(tokenA, tokenB, amountA, amountB, liquidity);
    }

    /// @notice Removes liquidity from a ERC20⇄WETH pool and receives ETH
    /// @param data The calldata containing function parameters
    /// @return amountToken The amount of token received
    /// @return amountETH The amount of ETH received
    function _removeLiquidityETH(bytes calldata data) internal returns (uint256 amountToken, uint256 amountETH) {
        (,, address token, uint256 liquidity, uint256 amountTokenMin, uint256 amountETHMin, uint256 deadline) =
            abi.decode(data[4:], (address, address, address, uint256, uint256, uint256, uint256));

        if (block.timestamp > deadline) revert DeadlineExpired();

        // Get the pair address
        address pair = factory.getPair(token, WETH);
        if (pair == address(0)) revert("Pair does not exist");

        // Approve the router to spend the liquidity tokens
        IERC20(pair).approve(address(router), liquidity);

        (amountToken, amountETH) =
            router.removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, msg.sender, deadline);

        if (amountToken < amountTokenMin || amountETH < amountETHMin) {
            revert SlippageExceeded();
        }

        // Transfer ETH to the sender
        (bool success,) = msg.sender.call{value: amountETH}("");
        if (!success) revert ETHTransferFailed();

        emit LiquidityRemovedETH(token, amountToken, amountETH, liquidity);
    }
}
