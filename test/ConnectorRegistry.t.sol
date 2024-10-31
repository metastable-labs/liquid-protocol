// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "forge-std/Test.sol";
import "../src/ConnectorRegistry.sol";

contract MockConnector {
    uint256 public getVersion = 1;
}

contract ConnectorRegistryTest is Test {
    ConnectorRegistry public registry;
    address public owner;
    address public testConnector1;
    address public testConnector2;
    address public testConnector3;

    function setUp() public {
        registry = new ConnectorRegistry();
        owner = address(this);
        testConnector1 = address(new MockConnector());
        testConnector2 = address(new MockConnector());
        testConnector3 = address(new MockConnector());
    }

    function testAddConnector() public {
        registry.addConnector(testConnector1, "TestConnector1");

        (string memory name, uint256 version, bool isActive) = registry.connectors(testConnector1);
        assertEq(name, "TestConnector1");
        assertEq(version, 1);
        assertTrue(isActive);

        assertEq(registry.connectorList(0), testConnector1);
        assertEq(registry.getConnectorCount(), 1);
    }

    function testAddMultipleConnectors() public {
        registry.addConnector(testConnector1, "TestConnector1");
        registry.addConnector(testConnector2, "TestConnector2");
        registry.addConnector(testConnector3, "TestConnector3");

        assertEq(registry.getConnectorCount(), 3);
        assertEq(registry.connectorList(0), testConnector1);
        assertEq(registry.connectorList(1), testConnector2);
        assertEq(registry.connectorList(2), testConnector3);

        assertTrue(registry.isApprovedConnector(testConnector1));
        assertTrue(registry.isApprovedConnector(testConnector2));
        assertTrue(registry.isApprovedConnector(testConnector3));
    }

    function test_RevertWhenAddingExistingConnector() public {
        registry.addConnector(testConnector1, "TestConnector1");
        vm.expectRevert(abi.encodeWithSelector(ConnectorRegistry.ConnectorAlreadyExists.selector, testConnector1, 1));
        registry.addConnector(testConnector1, "TestConnector1");
    }

    function test_RevertWhenUpdatingNonExistentConnector() public {
        vm.expectRevert(abi.encodeWithSelector(ConnectorRegistry.ConnectorDoesNotExist.selector, testConnector2));
        registry.updateConnectorName(testConnector2, "NonExistent");
    }

    function test_RevertWhenDeactivatingNonActiveConnector() public {
        registry.addConnector(testConnector1, "TestConnector1");
        registry.updateConnectorStatus(testConnector1, false);
        vm.expectRevert(abi.encodeWithSelector(ConnectorRegistry.StatusNotChanged.selector));
        registry.updateConnectorStatus(testConnector1, false);
    }

    function testDeactivateConnector() public {
        registry.addConnector(testConnector1, "TestConnector1");
        registry.updateConnectorStatus(testConnector1, false);

        (,, bool isActive) = registry.connectors(testConnector1);
        assertFalse(isActive);
    }

    function testIsApprovedConnector() public {
        registry.addConnector(testConnector1, "TestConnector1");
        assertTrue(registry.isApprovedConnector(testConnector1));

        registry.updateConnectorStatus(testConnector1, false);
        assertFalse(registry.isApprovedConnector(testConnector1));
    }
}
