// SPDX-License-Identifier: GNU
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import "../src/interface/IConnector.sol";

import {Strategy} from "../src/strategy.sol";
import {Oracle} from "../src/oracle.sol";
import {Engine} from "../src/engine.sol";

// connectors
import {MoonwellConnector} from "../src/protocols/lending/base/moonwell/main.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Strategy strategy = new Strategy();
        Engine engine = new Engine(address(strategy));
        Orcale oracle = new Oracle();

        MoonwellConnector mwConnector = new MoonwellConnector(
            "Moonwell Connector",
            IConnector.ConnectorType.LENDING;
            address(strategy),
            address(engine),
            address(oracle)
        );

        vm.stopBroadcast();
    }
}