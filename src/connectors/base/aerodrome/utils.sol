// SPDX-License-Identifier: GNU
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IRouter} from "@aerodrome/contracts/contracts/interfaces/IRouter.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IPool} from "@aerodrome/contracts/contracts/interfaces/IPool.sol";
import {AggregatorV3Interface, IPriceFeedRegistry} from "./interface.sol";
import {Babylonian} from "../lib/Babylonian.sol";
import "../common/constant.sol";

library AerodromeUtils is Constants {
    error PriceImpactTooHigh();
    error PriceDeviationTooHigh();

    function checkPriceRatio(address tokenA, address tokenB, uint256 amountA, uint256 amountB, bool stable)
        internal
        view
    {
        uint256 aDecMultiplier = 10 ** (18 - IERC20Metadata(tokenA).decimals());
        uint256 bDecMultiplier = 10 ** (18 - IERC20Metadata(tokenB).decimals());

        if (stable) {
            // Basic stable pool
            IPool pool = IPool(IRouter(router).getPair(tokenA, tokenB, true));

            require(amountA > 0 || amountB > 0, "Invalid amounts");

            uint256 amountOut;
            uint256 lowerBound;
            uint256 upperBound;

            if (amountA > 0) {
                // divide amount by 10 to reduce price impact of theoretical swap
                amountOut = pool.getAmountOut(amountA / 10, tokenA);
                lowerBound = mulDiv(amountA * aDecMultiplier, 10_000 - LIQ_SLIPPAGE, 10_000);
                upperBound = mulDiv(amountA * aDecMultiplier, 10_000 + LIQ_SLIPPAGE, 10_000);

                if (amountOut * bDecMultiplier * 10 < lowerBound || amountOut * bDecMultiplier * 10 > upperBound) {
                    revert PriceImpactTooHigh();
                }
            } else {
                // divide amount by 10 to reduce price impact of theoretical swap
                amountOut = pool.getAmountOut(amountB / 10, tokenB);

                lowerBound = mulDiv(amountB * bDecMultiplier, 10_000 - LIQ_SLIPPAGE, 10_000);
                upperBound = mulDiv(amountB * bDecMultiplier, 10_000 + LIQ_SLIPPAGE, 10_000);

                if (amountOut * aDecMultiplier * 10 < lowerBound || amountOut * aDecMultiplier * 10 > upperBound) {
                    revert PriceImpactTooHigh();
                }
            }
        } else {
            // Basic volatile pool
            (uint256 reserveA, uint256 reserveB) = IRouter(router).getReserves(tokenA, tokenB, false);

            // Ensure reserves are not zero to avoid division by zero
            require(reserveA > 0 && reserveB > 0, "Zero reserves");

            // Calculate the current price ratio from reserves
            uint256 currentRatio = mulDiv(reserveB, RAY, reserveA);

            // Calculate the input price ratio
            uint256 inputRatio;
            if (amountA > 0 && amountB > 0) {
                inputRatio = mulDiv(amountB, RAY, amountA);
            } else if (amountA > 0) {
                // If only amountA is provided, use getAmountOut to estimate amountB
                uint256 estimatedAmountB =
                    IPool(IRouter(router).getPair(tokenA, tokenB, false)).getAmountOut(amountA, tokenA);
                inputRatio = mulDiv(estimatedAmountB, RAY, amountA);
            } else if (amountB > 0) {
                // If only amountB is provided, use getAmountOut to estimate amountA
                uint256 estimatedAmountA =
                    IPool(IRouter(router).getPair(tokenA, tokenB, false)).getAmountOut(amountB, tokenB);
                inputRatio = mulDiv(amountB, RAY, estimatedAmountA);
            } else {
                revert("Invalid amounts");
            }

            // Calculate the allowed deviation
            uint256 allowedDeviation = mulDiv(currentRatio, LIQ_SLIPPAGE, 10_000);

            // Check if the input ratio is within the allowed deviation
            if (diff(inputRatio, currentRatio) > allowedDeviation) {
                revert PriceDeviationTooHigh();
            }
        }
    }

    function balanceTokenRatio(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB,
        bool stable,
        address router
    ) internal returns (uint256[] memory amounts, bool sellTokenA) {
        uint256 aDecMultiplier = 10 ** (18 - IERC20Metadata(tokenA).decimals());
        uint256 bDecMultiplier = 10 ** (18 - IERC20Metadata(tokenB).decimals());

        (uint256 reserveA, uint256 reserveB) = IRouter(router).getReserves(tokenA, tokenB, stable);

        uint256 x = reserveA;
        uint256 y = reserveB;
        uint256 a = amountA;
        uint256 b = amountB;

        sellTokenA = (a == 0) ? false : (b == 0) ? true : mulDiv(a, RAY, b) > mulDiv(x, RAY, y);

        uint256 tokensToSell;
        uint256 amountOutMin;

        if (!stable) {
            if (!sellTokenA) {
                tokensToSell = calculateAmountIn(y, x, b, a, bDecMultiplier, aDecMultiplier) / bDecMultiplier;
                uint256 amtToReceive = calculateAmountOut(tokensToSell, y, x);
                amountOutMin = (amtToReceive * 9999) / 10_000; // allow for 1bip of error
            } else {
                tokensToSell = calculateAmountIn(x, y, a, b, aDecMultiplier, bDecMultiplier);
                uint256 amtToReceive = calculateAmountOut(tokensToSell, x, y);
                amountOutMin = (amtToReceive * 9999) / 10_000; // allow for 1bip of error
            }
        } else {
            if (!sellTokenA) {
                uint256 valueA = (amountA * y) / x;
                uint256 valueDifference = amountB - valueA;
                tokensToSell = valueDifference / 2;
            } else {
                uint256 valueB = (amountB * x) / y;
                uint256 valueDifference = amountA - valueB;
                tokensToSell = valueDifference / 2;
            }
        }

        if (tokensToSell == 0) {
            return (new uint256[](2), sellTokenA);
        }

        // Perform the swap
        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route(sellTokenA ? tokenA : tokenB, sellTokenA ? tokenB : tokenA, stable);

        amounts =
            IRouter(router).swapExactTokensForTokens(tokensToSell, amountOutMin, routes, address(this), block.timestamp);

        return (amounts, sellTokenA);
    }

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

    function calculateAmountIn(uint256 x, uint256 y, uint256 a, uint256 b, uint256 aDec, uint256 bDec)
        internal
        pure
        returns (uint256)
    {
        // Normalize to 18 decimals
        x = x * aDec;
        a = a * aDec;

        y = y * bDec;
        b = b * bDec;

        // Perform calculations
        uint256 xy = (y * x) / WAD;
        uint256 bx = (b * x) / WAD;
        uint256 ay = (y * a) / WAD;

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
    }

    function calculateAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256)
    {
        return (reserveOut * 997 * amountIn) / (1000 * reserveIn + 997 * amountIn);
    }

    function diff(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : b - a;
    }
}