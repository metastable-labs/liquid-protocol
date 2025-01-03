// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console, Vm} from "forge-std/Test.sol";
import {Strategy} from "../../src/curators/strategy.sol";
import {Engine} from "../../src/curators/engine.sol";
import {Oracle} from "../../src/curators/oracle.sol";
import {AerodromeBasicConnector} from "../../src/protocols/dex/base/aerodrome-basic/main.sol";
import "../../src/curators/interface/IStrategy.sol";

contract StrategyTest is Test {
    Strategy public strategy;
    Engine public engine;
    Oracle public oracle;
    AerodromeBasicConnector public aerodromeBasicConnector;

    address constant cbBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant moonwell_cbBTC = 0xF877ACaFA28c19b96727966690b2f44d35aD5976;
    address constant moonwell_USDC = 0xEdc817A28E8B93B03976FBd4a3dDBc9f7D176c22;
    address constant aero_router = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address constant aero_cbbtc_udsc_lpt = 0x827922686190790b37229fd06084350E74485b72;

    function setUp() public {
        engine = new Engine();
        strategy = new Strategy(address(engine));
        oracle = new Oracle();

        aerodromeBasicConnector = new AerodromeBasicConnector(
            "Aero Connector", IConnector.ConnectorType.LENDING, address(strategy), address(engine), address(oracle)
        );
    }

    function test_Create_Strategy() public {
        string memory name = "cbBTC";
        string memory strategyDescription = "cbBTC strategy on base";
        uint256 minDeposit;
        uint256 maxTVL;
        uint256 performanceFee;

        ILiquidStrategy.Step[] memory steps = new ILiquidStrategy.Step[](3);

        // Step 0 - Supply half your cbBTC on Moonwell
        address[] memory _assetsIn0 = new address[](1);
        _assetsIn0[0] = cbBTC;
        steps[0] = ILiquidStrategy.Step({
            connector: address(aerodromeBasicConnector),
            actionType: IConnector.ActionType.SUPPLY,
            assetsIn: _assetsIn0,
            assetOut: moonwell_cbBTC,
            amountRatio: 5000,
            data: hex""
        });

        // Step 1 - Borrow USDC on Moonwell
        address[] memory _assetsIn1 = new address[](1);
        _assetsIn1[0] = moonwell_USDC;
        steps[1] = ILiquidStrategy.Step({
            connector: address(aerodromeBasicConnector),
            actionType: IConnector.ActionType.BORROW,
            assetsIn: _assetsIn1,
            assetOut: USDC,
            amountRatio: 5000,
            data: hex""
        });

        // Step2 - Supply cbBTC + USDC on Aerodrome
        address[] memory _assetsIn2 = new address[](1);
        _assetsIn2[0] = cbBTC;
        _assetsIn2[1] = USDC;
        steps[2] = ILiquidStrategy.Step({
            connector: address(aerodromeBasicConnector),
            actionType: IConnector.ActionType.SUPPLY,
            assetsIn: _assetsIn2,
            assetOut: aero_cbbtc_udsc_lpt,
            amountRatio: 10_000,
            data: hex""
        });

        // Start the recording event
        vm.recordLogs();

        vm.prank(address(0xAAAA));
        strategy.createStrategy(name, strategyDescription, steps, minDeposit);

        Vm.Log[] memory entries = vm.getRecordedLogs();

        // assert that strategy Ids are the same
        bytes32 strategyId = keccak256(abi.encodePacked(address(0xAAAA), name, strategyDescription));
        assertEq(entries[0].topics[1], strategyId);
    }
}
