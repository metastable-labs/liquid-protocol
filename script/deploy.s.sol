// SPDX-License-Identifier: GNU
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import "../src/interface/IConnector.sol";

import {Strategy} from "../src/curators/strategy.sol";
import {Oracle} from "../src/curators/oracle.sol";
import {Engine} from "../src/curators/engine.sol";

// connectors
import {MoonwellConnector} from "../src/protocols/lending/base/moonwell/main.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Engine engine = new Engine();
        Strategy strategy = new Strategy(address(engine));
        Oracle oracle = new Oracle();

        MoonwellConnector mwConnector = new MoonwellConnector(
            "Moonwell Connector", IConnector.ConnectorType.LENDING, address(strategy), address(engine), address(oracle)
        );

        vm.stopBroadcast();
    }
}
