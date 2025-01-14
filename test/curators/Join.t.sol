// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console, Vm} from "forge-std/Test.sol";
import {Engine} from "../../src/curators/engine.sol";
import {Oracle} from "../../src/curators/oracle.sol";
import {Strategy} from "../../src/curators/strategy.sol";
import {AerodromeBasicConnector} from "../../src/protocols/dex/base/aerodrome-basic/main.sol";
import {MoonwellConnector} from "../../src/protocols/lending/base/moonwell/main.sol";
import {MorphConnector} from "../../src/protocols/lending/base/morpho/main.sol";
import "../../src/curators/interface/IStrategy.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract JoinTest is Test {
    Engine public engine;
    Oracle public oracle;
    Strategy public strategy;
    AerodromeBasicConnector public aerodromeBasicConnector;
    MoonwellConnector public moonwellConnector;
    MorphConnector public morphConnector;

    address curator = 0xb8DD9c5614cb90bfe681A7d882d374224911d962;
    address user_WETH = 0x70aCDF2Ad0bf2402C957154f944c19Ef4e1cbAE1;
    address constant COMPTROLLER = 0xfBb21d0380beE3312B33c4353c8936a0F13EF26C;

    address constant cbBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant moonwell_WETH = 0x628ff693426583D9a7FB391E54366292F509D457;
    address constant moonwell_cbBTC = 0xF877ACaFA28c19b96727966690b2f44d35aD5976;
    address constant moonwell_USDC = 0xEdc817A28E8B93B03976FBd4a3dDBc9f7D176c22;
    address constant aero_router = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address constant metamorph_mwUSDC = 0xc1256Ae5FF1cf2719D4937adb3bbCCab2E00A2Ca;
    address constant aero_cbbtc_udsc_lpt = 0x827922686190790b37229fd06084350E74485b72;

    function setUp() public {
        uint256 forkId = vm.createFork("https://base-mainnet.g.alchemy.com/v2/kFEAtW9Zk37x4X6GUb9ZtMQfWi_d0z2j");
        vm.selectFork(forkId);

        vm.rollFork(24_474_060);

        vm.startPrank(address(0xB0b));
        engine = new Engine();
        strategy = new Strategy(address(engine));
        oracle = new Oracle();
        moonwellConnector = new MoonwellConnector(
            "Moonwell Connector", IConnector.ConnectorType.LENDING, address(strategy), address(engine), address(oracle)
        );
        morphConnector = new MorphConnector(
            "Morph Connector", IConnector.ConnectorType.LENDING, address(strategy), address(engine), address(oracle)
        );
        aerodromeBasicConnector = new AerodromeBasicConnector(
            "Aero Connector", IConnector.ConnectorType.LENDING, address(strategy), address(engine), address(oracle)
        );

        // toggle connectors
        strategy.toggleConnector(address(moonwellConnector));
        strategy.toggleConnector(address(morphConnector));
        strategy.toggleConnector(address(aerodromeBasicConnector));
        vm.stopPrank();
    }

    function test_USDC_WETH_AERODROME_SINGLE() public {
        bytes32 strategyId;
        {
            string memory name = "USDC / WETH";
            string memory strategyDescription = "USDC and WETH strategy on base";
            uint256 minDeposit;

            ILiquidStrategy.Step[] memory steps = new ILiquidStrategy.Step[](1);

            // Step 0 - Supply half your USDC on Moonwell
            address[] memory _assetsIn0 = new address[](2);
            _assetsIn0[0] = USDC;
            _assetsIn0[1] = WETH;
            steps[0] = ILiquidStrategy.Step({
                connector: address(aerodromeBasicConnector),
                actionType: IConnector.ActionType.SUPPLY,
                assetsIn: _assetsIn0,
                assetOut: 0xcDAC0d6c6C59727a65F871236188350531885C43,
                amountRatio: 5000,
                data: abi.encode(0, 1)
            });

            vm.prank(curator);
            strategy.createStrategy(name, strategyDescription, steps, minDeposit);

            strategyId = keccak256(abi.encodePacked(curator, name, strategyDescription));
        }

        uint256 a1 = 1000 * 10 ** (ERC20(USDC).decimals());
        uint256 a2 = 1 * 10 ** (ERC20(WETH).decimals());

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = a1;
        amounts[1] = a2;

        address[] memory assets = new address[](2);
        assets[0] = USDC;
        assets[1] = WETH;

        deal(USDC, address(0xb0b), a1);
        deal(WETH, address(0xb0b), a2);

        vm.startPrank(address(0xb0b));
        ERC20(USDC).approve(address(engine), a1);
        ERC20(WETH).approve(address(engine), a2);
        engine.join(strategyId, address(strategy), amounts);

        {
            (uint256[] memory totalDeposits, uint256 totalUsers, uint256 totalFeeGenerated, uint256 lastUpdated) =
                strategy.getStrategyStats(strategyId, assets);

            console.logUint(totalDeposits[0]);
            console.logUint(totalDeposits[1]);
            console.logUint(totalUsers);
            console.logUint(totalFeeGenerated);
            console.logUint(lastUpdated);
        }

        engine.exit(strategyId, address(strategy));

        console.logUint(ERC20(USDC).balanceOf(address(0xb0b)));
        console.logUint(ERC20(WETH).balanceOf(address(0xb0b)));

        vm.stopPrank();
    }

    function test_USDC_MOONWELL_SINGLE() public {
        string memory name = "USDC";
        string memory strategyDescription = "USDC strategy on base";
        uint256 minDeposit;

        ILiquidStrategy.Step[] memory steps = new ILiquidStrategy.Step[](1);

        // Step 0 - Supply half your USDC on Moonwell
        address[] memory _assetsIn0 = new address[](1);
        _assetsIn0[0] = USDC;
        steps[0] = ILiquidStrategy.Step({
            connector: address(moonwellConnector),
            actionType: IConnector.ActionType.SUPPLY,
            assetsIn: _assetsIn0,
            assetOut: moonwell_USDC,
            amountRatio: 5000,
            data: hex""
        });

        vm.prank(curator);
        strategy.createStrategy(name, strategyDescription, steps, minDeposit);

        bytes32 strategyId = keccak256(abi.encodePacked(curator, name, strategyDescription));

        uint256 a1 = 1 * 10 ** (ERC20(USDC).decimals());

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = a1;

        deal(USDC, address(0xb0b), a1);

        vm.startPrank(address(0xb0b));
        ERC20(USDC).approve(address(engine), a1);
        engine.join(strategyId, address(strategy), amounts);

        engine.exit(strategyId, address(strategy));

        console.logUint(ERC20(USDC).balanceOf(address(0xb0b)));

        vm.stopPrank();
    }

    function test_WETH_MORPHO_SINGLE() public {
        string memory name = "WETH";
        string memory strategyDescription = "WETH strategy on base";
        uint256 minDeposit;

        ILiquidStrategy.Step[] memory steps = new ILiquidStrategy.Step[](1);

        // Step 0 - Supply half your WETH on Moonwell
        address[] memory _assetsIn0 = new address[](1);
        _assetsIn0[0] = WETH;
        steps[0] = ILiquidStrategy.Step({
            connector: address(morphConnector),
            actionType: IConnector.ActionType.SUPPLY,
            assetsIn: _assetsIn0,
            assetOut: 0x6b13c060F13Af1fdB319F52315BbbF3fb1D88844,
            amountRatio: 5000,
            data: hex""
        });

        vm.prank(curator);
        strategy.createStrategy(name, strategyDescription, steps, minDeposit);

        bytes32 strategyId = keccak256(abi.encodePacked(curator, name, strategyDescription));

        uint256 a1 = 1 * 10 ** (ERC20(WETH).decimals());

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = a1;

        deal(WETH, address(0xb0b), a1);

        vm.startPrank(address(0xb0b));
        ERC20(WETH).approve(address(engine), a1);
        engine.join(strategyId, address(strategy), amounts);

        engine.exit(strategyId, address(strategy));

        console.logUint(ERC20(WETH).balanceOf(address(0xb0b)));

        vm.stopPrank();
    }

    function test_USDC_MORPHO_SINGLE() public {
        string memory name = "USDC_MORPHO";
        string memory strategyDescription = "USDC strategy on base";
        uint256 minDeposit;

        ILiquidStrategy.Step[] memory steps = new ILiquidStrategy.Step[](1);

        // Step 0 - Supply half your USDC on Moonwell
        address[] memory _assetsIn0 = new address[](1);
        _assetsIn0[0] = USDC;
        steps[0] = ILiquidStrategy.Step({
            connector: address(morphConnector),
            actionType: IConnector.ActionType.SUPPLY,
            assetsIn: _assetsIn0,
            assetOut: 0xc0c5689e6f4D256E861F65465b691aeEcC0dEb12,
            amountRatio: 5000,
            data: hex""
        });

        vm.prank(curator);
        strategy.createStrategy(name, strategyDescription, steps, minDeposit);

        bytes32 strategyId = keccak256(abi.encodePacked(curator, name, strategyDescription));

        uint256 a1 = 1 * 10 ** (ERC20(USDC).decimals());

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = a1;

        deal(USDC, address(0xb0b), a1);

        vm.startPrank(address(0xb0b));
        ERC20(USDC).approve(address(engine), a1);
        engine.join(strategyId, address(strategy), amounts);

        engine.exit(strategyId, address(strategy));

        console.logUint(ERC20(USDC).balanceOf(address(0xb0b)));

        vm.stopPrank();
    }

    function test_Join_Strategy_cbBTC() public {
        bytes32 strategyId = _createStrategy();
        uint256 a1 = 1 * 10 ** (ERC20(cbBTC).decimals());

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = a1;

        deal(cbBTC, address(0xb0b), a1);

        vm.startPrank(address(0xb0b));
        ERC20(cbBTC).approve(address(engine), a1);
        engine.join(strategyId, address(strategy), amounts);

        deal(USDC, address(strategy), 1);

        engine.exit(strategyId, address(strategy));

        console.logUint(ERC20(cbBTC).balanceOf(address(0xb0b)));

        vm.stopPrank();
    }

    function _createStrategy() internal returns (bytes32 strategyId) {
        string memory name = "cbBTC";
        string memory strategyDescription = "cbBTC strategy on base";
        uint256 minDeposit;

        ILiquidStrategy.Step[] memory steps = new ILiquidStrategy.Step[](3);

        // Step 0 - Supply half your cbBTC on Moonwell
        address[] memory _assetsIn0 = new address[](1);
        _assetsIn0[0] = cbBTC;
        steps[0] = ILiquidStrategy.Step({
            connector: address(moonwellConnector),
            actionType: IConnector.ActionType.SUPPLY,
            assetsIn: _assetsIn0,
            assetOut: moonwell_cbBTC,
            amountRatio: 5000,
            data: hex""
        });

        // Step 1 - Borrow USDC on Moonwell
        address[] memory _assetsIn1 = new address[](3);
        _assetsIn1[0] = cbBTC;
        _assetsIn1[1] = moonwell_cbBTC;
        _assetsIn1[2] = moonwell_USDC;
        steps[1] = ILiquidStrategy.Step({
            connector: address(moonwellConnector),
            actionType: IConnector.ActionType.BORROW,
            assetsIn: _assetsIn1,
            assetOut: USDC,
            amountRatio: 8000,
            data: hex""
        });

        // Step2 - Supply USDC on Morph
        address[] memory _assetsIn2 = new address[](1);
        _assetsIn2[0] = USDC;
        steps[2] = ILiquidStrategy.Step({
            connector: address(morphConnector),
            actionType: IConnector.ActionType.SUPPLY,
            assetsIn: _assetsIn2,
            assetOut: metamorph_mwUSDC,
            amountRatio: 10_000,
            data: hex""
        });

        vm.prank(curator);
        strategy.createStrategy(name, strategyDescription, steps, minDeposit);

        strategyId = keccak256(abi.encodePacked(curator, name, strategyDescription));
    }
}
