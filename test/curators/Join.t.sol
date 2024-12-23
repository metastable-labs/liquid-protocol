// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console, Vm} from "forge-std/Test.sol";
import {Engine} from "../../src/curators/engine.sol";
import {Oracle} from "../../src/curators/oracle.sol";
import {Strategy} from "../../src/curators/strategy.sol";
import {AerodromeBasicConnector} from "../../src/protocols/dex/base/aerodrome-basic/main.sol";
import {MoonwellConnector} from "../../src/protocols/lending/base/moonwell/main.sol";
import "../../src/curators/interface/IStrategy.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract JoinTest is Test {
    Engine public engine;
    Oracle public oracle;
    Strategy public strategy;
    AerodromeBasicConnector public aerodromeBasicConnector;
    MoonwellConnector public moonwellConnector;

    address curator = 0xb8DD9c5614cb90bfe681A7d882d374224911d962;
    address constant COMPTROLLER = 0xfBb21d0380beE3312B33c4353c8936a0F13EF26C;

    address constant cbBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant moonwell_cbBTC = 0xF877ACaFA28c19b96727966690b2f44d35aD5976;
    address constant moonwell_USDC = 0xEdc817A28E8B93B03976FBd4a3dDBc9f7D176c22;
    address constant aero_router = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address constant aero_cbbtc_udsc_lpt = 0x827922686190790b37229fd06084350E74485b72;

    function setUp() public {
        uint256 forkId = vm.createFork("https://base-mainnet.g.alchemy.com/v2/kFEAtW9Zk37x4X6GUb9ZtMQfWi_d0z2j");
        vm.selectFork(forkId);

        // strategy = Strategy(0x4368d53677c09995989a22DE5b31EfceAeD735ae);
        // engine = Engine(0xe7D11A96aB3813D8232a0711D4fa4f60E2f50B19);
        // oracle = Oracle(0x333Cd307bd0d8fDB3c38b14eacC4072FF548176B);
        // moonwellConnector = MoonwellConnector(0x01249b37d803573c071186BC4C3ea92872B93F5E);

        vm.startPrank(address(0xB0b));
        engine = new Engine();
        strategy = new Strategy(address(engine));
        oracle = new Oracle();
        moonwellConnector = new MoonwellConnector(
            "Moonwell Connector", IConnector.ConnectorType.LENDING, address(strategy), address(engine), address(oracle)
        );
        aerodromeBasicConnector = new AerodromeBasicConnector("Aero Connector", IConnector.ConnectorType.LENDING);

        // toggle connectors
        strategy.toggleConnector(address(moonwellConnector));
        vm.stopPrank();
    }

    function test_Join_Strategy() public {
        bytes32 strategyId = _createStrategy();
        uint256 a1 = 1 * 10 ** ERC20(cbBTC).decimals();

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = a1;

        vm.startPrank(curator);
        ERC20(cbBTC).approve(address(engine), a1);
        engine.join(strategyId, address(strategy), amounts);

        ILiquidStrategy.UserStats memory ss = strategy.getUserStrategyStats(strategyId, curator);

        assert(ERC20(USDC).balanceOf(address(moonwellConnector)) == 0);
        assert(ss.isActive);

        engine.exit(strategyId, address(strategy));

        ss = strategy.getUserStrategyStats(strategyId, curator);

        assert(!ss.isActive);

        vm.stopPrank();
    }

    function _createStrategy() internal returns (bytes32 strategyId) {
        string memory name = "cbBTC";
        string memory strategyDescription = "cbBTC strategy on base";
        uint256 minDeposit;

        ILiquidStrategy.Step[] memory steps = new ILiquidStrategy.Step[](2);

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
            amountRatio: 1000,
            data: hex""
        });

        vm.prank(curator);
        strategy.createStrategy(name, strategyDescription, steps, minDeposit);

        strategyId = keccak256(abi.encodePacked(curator, name, strategyDescription));
    }
}
