// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console, Vm} from "forge-std/Test.sol";
import {Engine} from "../../src/curators/engine.sol";
import {Oracle} from "../../src/curators/oracle.sol";
import {Strategy} from "../../src/curators/strategy.sol";
import {MoonwellConnector} from "../../src/protocols/lending/base/moonwell/main.sol";
import {MorphConnector} from "../../src/protocols/lending/base/morpho/main.sol";
import "../../src/curators/interface/IStrategy.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract JoinTest is Test {
    Engine public engine;
    Oracle public oracle;
    Strategy public strategy;
    MoonwellConnector public moonwellConnector;
    MorphConnector public morphConnector;

    address curator = 0xb8DD9c5614cb90bfe681A7d882d374224911d962;
    address constant COMPTROLLER = 0xfBb21d0380beE3312B33c4353c8936a0F13EF26C;

    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant moonwell_USDC = 0xEdc817A28E8B93B03976FBd4a3dDBc9f7D176c22;

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

        // toggle connectors
        strategy.toggleConnector(address(moonwellConnector));
        strategy.toggleConnector(address(morphConnector));

        // TOGGLE ASSETOUT
        engine.toggleAssetOut(moonwell_USDC);

        vm.stopPrank();
    }

    function test_USDC_MOONWELL_SINGLE() public {
        string memory name = "MALICIOUS STRATEGY";
        string memory strategyDescription = "MALICIOUS STRATEGY ON BASE";
        uint256 minDeposit;

        ILiquidStrategy.Step[] memory steps = new ILiquidStrategy.Step[](1);

        // Step 0 - Supply half your USDC on Moonwell
        address[] memory _assetsIn0 = new address[](1);
        _assetsIn0[0] = USDC;
        steps[0] = ILiquidStrategy.Step({
            connector: address(moonwellConnector),
            actionType: IConnector.ActionType.SUPPLY,
            assetsIn: _assetsIn0,
            assetOut: address(0xBad), // an assetOut address that hasn't been marked as a verified assetOut address
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
        ERC20(USDC).approve(address(engine), amounts[0]);

        // EXPECT CALL TO REVERT
        vm.expectRevert();
        engine.join(strategyId, address(strategy), amounts);

        vm.stopPrank();
    }
}
