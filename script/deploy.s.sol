// script/Deploy.s.sol
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "./contracts.s.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        ContractDeploymentScript deploymentScript = new ContractDeploymentScript();
        deploymentScript.deploy();

        vm.stopBroadcast();
    }
}
