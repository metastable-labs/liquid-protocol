// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface MorphInterface {
    /**
     * User Interface **
     */
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
}
