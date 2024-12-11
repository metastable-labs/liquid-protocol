// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface MErc20Interface {
    /**
     * User Interface **
     */
    function mint(uint256 mintAmount) external returns (uint256);
    function redeem(uint256 redeemTokens) external returns (uint256);
    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);
    function borrow(uint256 borrowAmount) external returns (uint256);
    function repayBorrow(uint256 repayAmount) external returns (uint256);
    function repayBorrowBehalf(address borrower, uint256 repayAmount) external returns (uint256);
    // function liquidateBorrow(address borrower, uint256 repayAmount, MTokenInterface mTokenCollateral)
    //     external
    //     returns (uint256);
    // function sweepToken(EIP20NonStandardInterface token) external;

    /**
     * Admin Functions **
     */
    function _addReserves(uint256 addAmount) external returns (uint256);
}

interface ComptrollerInterface {
    /// @notice Indicator that this is a Comptroller contract (for inspection)
    // bool public constant isComptroller = true;

    /**
     * Assets You Are In **
     */
    function enterMarkets(address[] calldata mTokens) external returns (uint256[] memory);
    function exitMarket(address mToken) external returns (uint256);
}
