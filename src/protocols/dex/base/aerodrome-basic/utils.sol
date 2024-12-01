// SPDX-License-Identifier: GNU
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IRouter} from "@aerodrome/contracts/contracts/interfaces/IRouter.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IPool} from "@aerodrome/contracts/contracts/interfaces/IPool.sol";
import {IPoolFactory} from "@aerodrome/contracts/contracts/interfaces/factories/IPoolFactory.sol";

import {IWETH} from "./interface.sol";
import {Babylonian} from "../../../../lib/Babylonian.sol";

/// @title AerodromeUtils
/// @notice A library for Aerodrome-specific utilities and calculations
/// @dev This library contains helper functions for price checks, token ratio balancing, and liquidity operations
library AerodromeUtils {
    error AerodromeUtils_ExceededMaxPriceImpact();
    error AerodromeUtils_ExceededMaxSlippage();
    error AerodromeUtils_ExceededMaxValueLoss();

    uint256 internal constant WAD = 1e18;
    uint256 internal constant RAY = 1e27;
    uint256 internal constant BIPS = 1e4; // fee denominator

    uint256 internal constant MAX_PRICE_IMPACT = 100; // 1%

    address internal constant WETH = 0x4200000000000000000000000000000000000006;
    address internal constant AERODROME_ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address internal constant AERODROME_FACTORY = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;

    /// @notice Balances the token ratio before adding liquidity
    /// @dev Performs necessary swaps to balance the token amounts according to the pool's current ratio
    /// @param tokenA The address of the first token
    /// @param tokenB The address of the second token
    /// @param amountA The amount of tokenA
    /// @param amountB The amount of tokenB
    /// @param stable Boolean indicating if it's a stable pool
    /// @return amounts An array containing the swapped amounts
    /// @return sellTokenA Boolean indicating whether tokenA was sold in the swap

    function balanceTokenRatio(address tokenA, address tokenB, uint256 amountA, uint256 amountB, bool stable)
        internal
        returns (uint256[] memory amounts, bool sellTokenA)
    {
        uint256 aDecMultiplier = 10 ** (18 - IERC20Metadata(tokenA).decimals());
        uint256 bDecMultiplier = 10 ** (18 - IERC20Metadata(tokenB).decimals());

        (uint256 reserveA, uint256 reserveB) =
            IRouter(AERODROME_ROUTER).getReserves(tokenA, tokenB, stable, IRouter(AERODROME_ROUTER).defaultFactory());

        address pool = IPoolFactory(AERODROME_FACTORY).getPool(tokenA, tokenB, stable);
        uint256 swapFee = IPoolFactory(AERODROME_FACTORY).getFee(pool, stable);

        uint256 x = reserveA;
        uint256 y = reserveB;
        uint256 a = amountA;
        uint256 b = amountB;

        sellTokenA = (a == 0) ? false : (b == 0) ? true : mulDiv(a, RAY, b) > mulDiv(x, RAY, y);

        uint256 tokensToSell;

        if (!sellTokenA) {
            tokensToSell = calculateAmountIn(y, x, b, a, bDecMultiplier, aDecMultiplier, swapFee, stable);
        } else {
            tokensToSell = calculateAmountIn(x, y, a, b, aDecMultiplier, bDecMultiplier, swapFee, stable);
        }

        if (tokensToSell == 0) {
            return (new uint256[](2), sellTokenA);
        }

        // Perform the swap
        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route(
            sellTokenA ? tokenA : tokenB,
            sellTokenA ? tokenB : tokenA,
            stable,
            IRouter(AERODROME_ROUTER).defaultFactory()
        );

        IERC20(sellTokenA ? tokenA : tokenB).approve(AERODROME_ROUTER, tokensToSell);
        amounts =
            IRouter(AERODROME_ROUTER).swapExactTokensForTokens(tokensToSell, 0, routes, address(this), block.timestamp);

        return (amounts, sellTokenA);
    }

    function updateAmountsIn(uint256 a, uint256 b, bool sellTokenA, uint256[] memory amounts)
        internal
        pure
        returns (uint256 amountAIn, uint256 amountBIn)
    {
        if (sellTokenA) {
            amountAIn = a - amounts[0];
            amountBIn = b + amounts[1];
        } else {
            amountBIn = b - amounts[0];
            amountAIn = a + amounts[1];
        }
    }

    function reserveRatio(address pool) internal view returns (uint256) {
        (uint256 reserveA, uint256 reserveB,) = IPool(pool).getReserves();
        return mulDiv(reserveA, RAY, reserveB);
    }

    function checkPriceImpact(address pool, uint256 ratioBefore) internal view returns (uint256) {
        uint256 ratioAfter = reserveRatio(pool);

        uint256 diffBips = (diff(ratioAfter, ratioBefore) * BIPS) / ratioBefore;
        if (diffBips > MAX_PRICE_IMPACT) {
            revert AerodromeUtils_ExceededMaxPriceImpact();
        } // 1%
    }

    function checkValueOut(
        uint256 liquidity,
        address tokenA,
        address tokenB,
        bool stable,
        uint256 amountAMin,
        uint256 amountBMin,
        uint256 amountAInitial,
        uint256 amountBInitial
    ) internal view returns (uint256) {
        // Calculate amountAOut, amountBOut
        address pool = IPoolFactory(AERODROME_FACTORY).getPool(tokenA, tokenB, stable);

        address factory = IPool(pool).factory();
        (uint256 amountAOut, uint256 amountBOut) =
            IRouter(AERODROME_ROUTER).quoteRemoveLiquidity(tokenA, tokenB, stable, factory, liquidity);

        // Ensure it meets the minimum amounts, computed offchain using `quoteDepositLiquidity()`
        if (amountAOut < amountAMin || amountBOut < amountBMin) {
            revert AerodromeUtils_ExceededMaxSlippage();
        }

        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route(tokenB, tokenA, stable, factory);

        uint256[] memory convertedBToA = IRouter(AERODROME_ROUTER).getAmountsOut(amountBInitial, routes);
        uint256 valueIn = amountAInitial + convertedBToA[1];

        uint256 leftoverA = subFloorZero(amountAInitial, amountAOut);
        uint256 leftoverB = subFloorZero(amountBInitial, amountBOut);

        convertedBToA = IRouter(AERODROME_ROUTER).getAmountsOut(amountBOut + leftoverB, routes);
        uint256 valueOut = amountAOut + leftoverA + convertedBToA[1];

        // Check that value received is at least 98% of value provided
        // Note: These values are determined based on spot price, but the earlier slippage check is used to prevent price manipulation
        // This check is a last resort, to prevent loss of funds in low liquidity pools
        if (valueOut < valueIn) {
            uint256 diffBips = ((valueIn - valueOut) * BIPS) / valueIn;
            if (diffBips > 200) revert AerodromeUtils_ExceededMaxValueLoss();
        }
    }

    /// @notice Returns leftover tokens to the recipient
    /// @dev Handles both ERC20 tokens and wrapped ETH
    /// @param tokenA The address of the first token
    /// @param tokenB The address of the second token
    /// @param leftoverA The amount of leftover tokenA
    /// @param leftoverB The amount of leftover tokenB
    /// @param recipient The address to receive the leftover tokens
    function returnLeftovers(address tokenA, address tokenB, uint256 leftoverA, uint256 leftoverB, address recipient)
        internal
    {
        if (leftoverA > 0) {
            if (tokenA == WETH) {
                // Unwrap WETH to ETH and send
                IWETH(WETH).withdraw(leftoverA);
                (bool success,) = recipient.call{value: leftoverA}("");
                require(success, "ETH transfer failed");
            } else {
                IERC20(tokenA).transfer(recipient, leftoverA);
            }
        }
        if (leftoverB > 0) {
            if (tokenB == WETH) {
                // Unwrap WETH to ETH and send
                IWETH(WETH).withdraw(leftoverB);
                (bool success,) = recipient.call{value: leftoverB}("");
                require(success, "ETH transfer failed");
            } else {
                IERC20(tokenB).transfer(recipient, leftoverB);
            }
        }
    }

    /// @notice Performs a multiplication followed by a division
    /// @dev Uses assembly for gas optimization and to prevent overflow
    /// @param x The first factor
    /// @param y The second factor
    /// @param denominator The divisor
    /// @return result The result of (x * y) / denominator
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        uint256 prod0;
        uint256 prod1;
        assembly {
            let mm := mulmod(x, y, not(0))
            prod0 := mul(x, y)
            prod1 := sub(sub(mm, prod0), lt(mm, prod0))
        }

        if (prod1 == 0) {
            require(denominator > 0);
            assembly {
                result := div(prod0, denominator)
            }
            return result;
        }

        require(denominator > prod1);

        uint256 remainder;
        assembly {
            remainder := mulmod(x, y, denominator)
        }
        assembly {
            prod1 := sub(prod1, gt(remainder, prod0))
            prod0 := sub(prod0, remainder)
        }

        uint256 twos = denominator & (~denominator + 1);
        assembly {
            denominator := div(denominator, twos)
        }

        assembly {
            prod0 := div(prod0, twos)
        }
        assembly {
            twos := add(div(sub(0, twos), twos), 1)
        }
        prod0 |= prod1 * twos;

        uint256 inv = (3 * denominator) ^ 2;
        inv *= 2 - denominator * inv;
        inv *= 2 - denominator * inv;
        inv *= 2 - denominator * inv;
        inv *= 2 - denominator * inv;
        inv *= 2 - denominator * inv;
        inv *= 2 - denominator * inv;

        result = prod0 * inv;
        return result;
    }

    /// @notice Calculates the amount of tokens to input for a swap
    /// @dev Uses a complex formula to determine the optimal input amount
    /// @param x Pool reserve of the token to sell
    /// @param y Pool reserve of the token to buy
    /// @param a User's amount of the token to sell
    /// @param b User's amount of the token to buy
    /// @param aDec Decimal multiplier for tokenA
    /// @param bDec Decimal multiplier for tokenB
    /// @return The calculated input amount
    function calculateAmountIn(
        uint256 x,
        uint256 y,
        uint256 a,
        uint256 b,
        uint256 aDec,
        uint256 bDec,
        uint256 swapFee,
        bool stable
    ) internal pure returns (uint256) {
        // Normalize to 18 decimals
        x = x * aDec;
        a = a * aDec;

        y = y * bDec;
        b = b * bDec;

        // Obtain intermediate terms
        uint256 xy = (y * x) / WAD;
        uint256 bx = (b * x) / WAD;
        uint256 ay = (y * a) / WAD;

        if (stable) {
            return ((ay - bx) * WAD) / (y + x) / aDec;
        } else if (swapFee == 30) {
            // Compute the square root term
            uint256 innerTerm = (xy + bx) * (3_988_009 * xy + 9 * bx + 3_988_000 * ay);
            uint256 sqrtTerm = Babylonian.sqrt(innerTerm);

            // Compute the numerator
            uint256 numerator = sqrtTerm - 1997 * (xy + bx);

            // Compute the denominator
            uint256 denominator = 1994 * (y + b);

            // Calculate the final value of amountIn
            uint256 amountIn = (numerator * WAD) / denominator;

            return amountIn / aDec;
        } else {
            // Assumes swapFee = 100 (1%)
            // Compute the square root term
            uint256 innerTerm = (xy + bx) * (39_601 * xy + bx + 39_600 * ay);
            uint256 sqrtTerm = Babylonian.sqrt(innerTerm);

            // Compute the numerator
            uint256 numerator = sqrtTerm - 199 * (xy + bx);

            // Compute the denominator
            uint256 denominator = 198 * (y + b);

            // Calculate the final value of amountIn
            uint256 amountIn = (numerator * WAD) / denominator;

            return amountIn / aDec;
        }
    }

    /// @notice Calculates the absolute difference between two numbers
    /// @param a The first number
    /// @param b The second number
    /// @return The absolute difference |a - b|

    function diff(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : b - a;
    }

    function subFloorZero(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : 0;
    }

    function quoteDepositLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 amountAInitial,
        uint256 amountBInitial,
        bool balanceTokenRatio
    ) internal view returns (uint256 amountAOut, uint256 amountBOut) {
        uint256 amountALeft = amountAInitial;
        uint256 amountBLeft = amountBInitial;

        address pool = IPoolFactory(AERODROME_FACTORY).getPool(tokenA, tokenB, stable);
        address factory = IPool(pool).factory();
        IRouter aerodromeRouter = IRouter(AERODROME_ROUTER);

        uint256 liquidityDeposited;
        for (uint256 i = 0; i < 2; i++) {
            if (balanceTokenRatio) {
                (uint256[] memory amounts, bool sellTokenA) =
                    quoteBalanceTokenRatio(tokenA, tokenB, amountALeft, amountBLeft, stable);

                (amountALeft, amountBLeft) = updateAmountsIn(amountALeft, amountBLeft, sellTokenA, amounts);
            }

            (uint256 amountADeposited, uint256 amountBDeposited, uint256 liquidity) =
                aerodromeRouter.quoteAddLiquidity(tokenA, tokenB, stable, factory, amountALeft, amountBLeft);

            amountALeft -= amountADeposited;
            amountBLeft -= amountBDeposited;

            liquidityDeposited += liquidity;

            if (!stable || !balanceTokenRatio) break; // only iterate once for volatile pairs, or if not balancing token ratio
        }

        (amountAOut, amountBOut) =
            aerodromeRouter.quoteRemoveLiquidity(tokenA, tokenB, stable, factory, liquidityDeposited);
    }

    // Simulates balanceTokenRatio(), without any state changes
    function quoteBalanceTokenRatio(address tokenA, address tokenB, uint256 amountA, uint256 amountB, bool stable)
        internal
        view
        returns (uint256[] memory amounts, bool sellTokenA)
    {
        uint256 aDecMultiplier = 10 ** (18 - IERC20Metadata(tokenA).decimals());
        uint256 bDecMultiplier = 10 ** (18 - IERC20Metadata(tokenB).decimals());

        (uint256 reserveA, uint256 reserveB) =
            IRouter(AERODROME_ROUTER).getReserves(tokenA, tokenB, stable, IRouter(AERODROME_ROUTER).defaultFactory());

        address pool = IPoolFactory(AERODROME_FACTORY).getPool(tokenA, tokenB, stable);
        uint256 swapFee = IPoolFactory(AERODROME_FACTORY).getFee(pool, stable);

        uint256 x = reserveA;
        uint256 y = reserveB;
        uint256 a = amountA;
        uint256 b = amountB;

        sellTokenA = (a == 0) ? false : (b == 0) ? true : mulDiv(a, RAY, b) > mulDiv(x, RAY, y);

        uint256 tokensToSell;

        if (!sellTokenA) {
            tokensToSell = calculateAmountIn(y, x, b, a, bDecMultiplier, aDecMultiplier, swapFee, stable);
        } else {
            tokensToSell = calculateAmountIn(x, y, a, b, aDecMultiplier, bDecMultiplier, swapFee, stable);
        }
        if (tokensToSell == 0) {
            return (new uint256[](2), sellTokenA);
        }

        // Quote the swap
        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route(
            sellTokenA ? tokenA : tokenB,
            sellTokenA ? tokenB : tokenA,
            stable,
            IRouter(AERODROME_ROUTER).defaultFactory()
        );

        amounts = IRouter(AERODROME_ROUTER).getAmountsOut(tokensToSell, routes);

        return (amounts, sellTokenA);
    }
}
