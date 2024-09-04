// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "forge-std/Test.sol";
import "../src/ConnectorRegistry.sol";

contract ConnectorRegistryTest is Test {
    ConnectorRegistry public registry;
    address public owner;
    address public testConnector1;
    address public testConnector2;

    function setUp() public {
        registry = new ConnectorRegistry();
        owner = address(this);
        testConnector1 = address(0x1);
        testConnector2 = address(0x2);
    }

    function testAddConnector() public {
        registry.addConnector(testConnector1, "TestConnector1", 1);

        (string memory name, uint256 version, bool isActive) = registry.connectors(testConnector1);
        assertEq(name, "TestConnector1");
        assertEq(version, 1);
        assertTrue(isActive);
    }

    function testAddConnectorNonOwner() public {
        vm.prank(address(0x3));
        vm.expectRevert("Ownable: caller is not the owner");
        registry.addConnector(testConnector1, "TestConnector1", 1);
    }

    function testAddExistingConnector() public {
        registry.addConnector(testConnector1, "TestConnector1", 1);
        vm.expectRevert(abi.encodeWithSelector(ConnectorRegistry.ConnectorAlreadyExists.selector, testConnector1));
        registry.addConnector(testConnector1, "TestConnector1", 2);
    }

    function testUpdateConnector() public {
        registry.addConnector(testConnector1, "TestConnector1", 1);
        registry.updateConnector(testConnector1, "UpdatedConnector1", 2);

        (string memory name, uint256 version, bool isActive) = registry.connectors(testConnector1);
        assertEq(name, "UpdatedConnector1");
        assertEq(version, 2);
        assertTrue(isActive);
    }

    function testUpdateNonExistentConnector() public {
        vm.expectRevert(abi.encodeWithSelector(ConnectorRegistry.ConnectorDoesNotExist.selector, testConnector2));
        registry.updateConnector(testConnector2, "NonExistent", 1);
    }

    function testDeactivateConnector() public {
        registry.addConnector(testConnector1, "TestConnector1", 1);
        registry.deactivateConnector(testConnector1);

        (,, bool isActive) = registry.connectors(testConnector1);
        assertFalse(isActive);
    }

    function testDeactivateNonActiveConnector() public {
        registry.addConnector(testConnector1, "TestConnector1", 1);
        registry.deactivateConnector(testConnector1);

        vm.expectRevert(abi.encodeWithSelector(ConnectorRegistry.ConnectorNotActive.selector, testConnector1));
        registry.deactivateConnector(testConnector1);
    }

    function testIsApprovedConnector() public {
        registry.addConnector(testConnector1, "TestConnector1", 1);
        assertTrue(registry.isApprovedConnector(testConnector1));

        registry.deactivateConnector(testConnector1);
        assertFalse(registry.isApprovedConnector(testConnector1));
    }
}
