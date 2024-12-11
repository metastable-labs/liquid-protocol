// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Oracle} from "../../src/curators/oracle.sol";
import {Constants} from "../../src/protocols/common/constant.sol";

contract OracleTest is Test, Constants {
    Oracle public oracle;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
        oracle = new Oracle();
    }

    function test_Price_price() public {
        uint256 x = uint256(oracle.getLatestAnswer(SEQUENCER_UPTIME_FEED, CBBTC_USD));
        uint256 y = uint256(oracle.getLatestAnswer(SEQUENCER_UPTIME_FEED, ETH_USD));

        // console.logUint(x);
        // console.logUint(y);

        // price of 1 x in terms of y
        uint256 z = oracle.getTokenAPriceInTokenB(x, 8, y, 8);

        console.logUint(z); // scaled to 18 decimals
    }
}
