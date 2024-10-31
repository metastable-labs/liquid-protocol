// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import "src/ConnectorRegistry.sol";
import "src/BaseConnector.sol";
import "src/connectors/base/aerodrome/main.sol";
import "src/ConnectorPlugin.sol";

contract ContractDeploymentScript is Script {
    ConnectorRegistry public registry;
    ConnectorPlugin public plugin;
    AerodromeConnector public aerodromeConnector;

    event ContractsDeployed(address indexed registry, address indexed plugin, address indexed aerodromeConnector);

    function run() external {
        uint256 deployer = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployer);
        // Deploy ConnectorRegistry
        registry = new ConnectorRegistry();

        // Deploy ConnectorPlugin
        plugin = new ConnectorPlugin(address(registry));

        // Deploy AerodromeConnector
        aerodromeConnector = new AerodromeConnector("AerodromeConnector", 1, address(plugin));

        // Add AerodromeConnector to the registry
        registry.addConnector(address(aerodromeConnector), "AerodromeConnector");

        // Emit event with deployed contract addresses
        emit ContractsDeployed(address(registry), address(plugin), address(aerodromeConnector));

        vm.stopBroadcast();
    }
}
