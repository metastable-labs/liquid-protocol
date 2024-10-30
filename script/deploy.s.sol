// script/Deploy.s.sol
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "./contracts.s.sol";

contract DeployScript is Script {
    function run() external {
        ContractDeploymentScript deploymentScript = new ContractDeploymentScript();
        deploymentScript.deploy();
    }
}
