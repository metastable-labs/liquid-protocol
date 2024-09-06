// SPDX-License-Identifier: GNU
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IRouter} from "@aerodrome/contracts/contracts/interfaces/IRouter.sol";
import {IPool} from "@aerodrome/contracts/contracts/interfaces/IPool.sol";
import {IPoolFactory} from "@aerodrome/contracts/contracts/interfaces/factories/IPoolFactory.sol";
import "../../../BaseConnector.sol";
import "../common/constant.sol";
import "./utils.sol";
import "./interface.sol";
import "./events.sol";

contract AerodromeConnector is BaseConnector, Constants, AerodromeEvents {
    IRouter public immutable aerodromeRouter;
    IPoolFactory public immutable aerodromeFactory;

    error InvalidSelector();
    error DeadlineExpired();
    error InsufficientLiquidity();
    error SlippageExceeded();

    constructor(string memory name, uint256 version) BaseConnector(name, version) {
        aerodromeRouter = IRouter(AERODROME_ROUTER);
        aerodromeFactory = IPoolFactory(AERODROME_FACTORY);
    }

    receive() external payable {}

    function execute(bytes calldata data) external payable override returns (bytes memory) {
        bytes4 selector = bytes4(data[:4]);

        if (selector == aerodromeRouter.addLiquidity.selector) {
            (uint256 amountA, uint256 amountB, uint256 liquidity) = _depositBasicLiquidity(data);
            return abi.encode(amountA, amountB, liquidity);
        } else if (selector == aerodromeRouter.removeLiquidity.selector) {
            (uint256 amountA, uint256 amountB) = _removeBasicLiquidity(data);
            return abi.encode(amountA, amountB);
        }

        revert InvalidSelector();
    }

    function _depositBasicLiquidity(bytes calldata data)
        internal
        returns (uint256 amountAOut, uint256 amountBOut, uint256 liquidity)
    {
        (
            address tokenA,
            address tokenB,
            bool stable,
            uint256 amountADesired,
            uint256 amountBDesired,
            uint256 amountAMin,
            uint256 amountBMin,
            address to,
            uint256 deadline
        ) = abi.decode(data[4:], (address, address, bool, uint256, uint256, uint256, uint256, address, uint256));

        if (block.timestamp > deadline) revert DeadlineExpired();

        // Check price ratio
        AerodromeUtils.checkPriceRatio(
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            stable,
            address(aerodromeRouter),
            address(aerodromeFactory),
            LIQ_SLIPPAGE
        );

        // Balance token ratio before depositing
        (uint256[] memory amounts, bool sellTokenA) = AerodromeUtils.balanceTokenRatio(
            tokenA, tokenB, amountADesired, amountBDesired, stable, address(aerodromeRouter)
        );

        // Update token amounts after swaps
        if (sellTokenA) {
            amountADesired -= amounts[0];
            amountBDesired += amounts[1];
        } else {
            amountBDesired -= amounts[0];
            amountADesired += amounts[1];
        }

        IERC20(tokenA).approve(address(aerodromeRouter), amountADesired);
        IERC20(tokenB).approve(address(aerodromeRouter), amountBDesired);

        // For volatile pairs: calculate minimum amount out with 0.5% slippage
        if (!stable) {
            amountAMin = AerodromeUtils.mulDiv(amountADesired, 10_000 - LIQ_SLIPPAGE, 10_000);
            amountBMin = AerodromeUtils.mulDiv(amountBDesired, 10_000 - LIQ_SLIPPAGE, 10_000);
        }

        // Add liquidity to the basic pool
        (amountAOut, amountBOut, liquidity) = aerodromeRouter.addLiquidity(
            tokenA, tokenB, stable, amountADesired, amountBDesired, amountAMin, amountBMin, to, deadline
        );

        if (liquidity == 0) revert InsufficientLiquidity();

        uint256 leftoverA = amountADesired - amountAOut;
        uint256 leftoverB = amountBDesired - amountBOut;

        AerodromeUtils.returnLeftovers(tokenA, tokenB, leftoverA, leftoverB, msg.sender, WETH_ADDRESS);

        emit LiquidityAdded(tokenA, tokenB, amountAOut, amountBOut, liquidity);
    }

    function _removeBasicLiquidity(bytes calldata data) internal returns (uint256 amountA, uint256 amountB) {
        (
            address tokenA,
            address tokenB,
            bool stable,
            uint256 liquidity,
            uint256 amountAMin,
            uint256 amountBMin,
            address to,
            uint256 deadline
        ) = abi.decode(data[4:], (address, address, bool, uint256, uint256, uint256, address, uint256));

        if (block.timestamp > deadline) revert DeadlineExpired();

        // Get the pair address
        address pair = aerodromeFactory.getPool(tokenA, tokenB, stable);
        if (pair == address(0)) revert("Pair does not exist");

        // Approve the router to spend the liquidity tokens
        IERC20(pair).approve(address(aerodromeRouter), liquidity);

        // Transfer liquidity tokens from the smart wallet to this contract
        IERC20(pair).transferFrom(msg.sender, address(this), liquidity);

        (amountA, amountB) =
            aerodromeRouter.removeLiquidity(tokenA, tokenB, stable, liquidity, amountAMin, amountBMin, to, deadline);

        if (amountA < amountAMin || amountB < amountBMin) {
            revert SlippageExceeded();
        }

        emit LiquidityRemoved(tokenA, tokenB, amountA, amountB, liquidity);
    }
}
