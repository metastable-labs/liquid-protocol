// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IWETH {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}

/// @title LP staking functionality
/// @notice Gauge interface for interacting with gauge contract for distribution of emissions by address
interface IGauge {
    function deposit(uint256 _amount, address _recipient) external;
    function withdraw(uint256 _amount) external;
    function getReward(address _account) external;
    function rewardToken() external view returns (address);
    function balanceOf(address) external view returns (uint256);
    function stakingToken() external view returns (address);
}

/// @title Router token swapping functionality
/// @notice Functions for swapping tokens via CL
interface ISwapRouterV3 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        int24 tickSpacing;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another token
    /// @param params The parameters necessary for the swap, encoded as `ExactInputSingleParams` in calldata
    /// @return amountOut The amount of the received token
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}
