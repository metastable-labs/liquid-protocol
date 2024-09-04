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

        (string memory name, uint256 version, bool isActive) = registry.connectors(testConnector1, 1);
        assertEq(name, "TestConnector1");
        assertEq(version, 1);
        assertTrue(isActive);
        assertEq(registry.getLatestConnectorVersion(testConnector1), 1);
    }

    function testAddConnectorNonOwner() public {
        vm.prank(address(0x3));
        vm.expectRevert("Ownable: caller is not the owner");
        registry.addConnector(testConnector1, "TestConnector1", 1);
    }

    function testAddExistingConnector() public {
        registry.addConnector(testConnector1, "TestConnector1", 1);
        vm.expectRevert(abi.encodeWithSelector(ConnectorRegistry.ConnectorAlreadyExists.selector, testConnector1, 1));
        registry.addConnector(testConnector1, "TestConnector1", 1);
    }

    function testAddLowerVersion() public {
        registry.addConnector(testConnector1, "TestConnector1", 2);
        vm.expectRevert(abi.encodeWithSelector(ConnectorRegistry.InvalidVersionUpdate.selector, testConnector1, 2, 1));
        registry.addConnector(testConnector1, "TestConnector1", 1);
    }

    function testUpdateConnector() public {
        registry.addConnector(testConnector1, "TestConnector1", 1);
        registry.updateConnector(testConnector1, "UpdatedConnector1", 1);

        (string memory name, uint256 version, bool isActive) = registry.connectors(testConnector1, 1);
        assertEq(name, "UpdatedConnector1");
        assertEq(version, 1);
        assertTrue(isActive);
    }

    function testUpdateNonExistentConnector() public {
        vm.expectRevert(
            abi.encodeWithSelector(ConnectorRegistry.ConnectorVersionDoesNotExist.selector, testConnector2, 1)
        );
        registry.updateConnector(testConnector2, "NonExistent", 1);
    }

    function testDeactivateConnector() public {
        registry.addConnector(testConnector1, "TestConnector1", 1);
        registry.deactivateConnector(testConnector1, 1);

        (,, bool isActive) = registry.connectors(testConnector1, 1);
        assertFalse(isActive);
    }

    function testDeactivateNonActiveConnector() public {
        registry.addConnector(testConnector1, "TestConnector1", 1);
        registry.deactivateConnector(testConnector1, 1);

        vm.expectRevert(abi.encodeWithSelector(ConnectorRegistry.ConnectorNotActive.selector, testConnector1, 1));
        registry.deactivateConnector(testConnector1, 1);
    }

    function testIsApprovedConnector() public {
        registry.addConnector(testConnector1, "TestConnector1", 1);
        assertTrue(registry.isApprovedConnector(testConnector1, 1));

        registry.deactivateConnector(testConnector1, 1);
        assertFalse(registry.isApprovedConnector(testConnector1, 1));
    }

    function testGetLatestConnectorVersion() public {
        registry.addConnector(testConnector1, "TestConnector1", 1);
        assertEq(registry.getLatestConnectorVersion(testConnector1), 1);

        registry.addConnector(testConnector1, "TestConnector1v2", 2);
        assertEq(registry.getLatestConnectorVersion(testConnector1), 2);
    }

    function testMultipleVersions() public {
        registry.addConnector(testConnector1, "TestConnector1v1", 1);
        registry.addConnector(testConnector1, "TestConnector1v2", 2);
        registry.addConnector(testConnector1, "TestConnector1v3", 3);

        assertTrue(registry.isApprovedConnector(testConnector1, 1));
        assertTrue(registry.isApprovedConnector(testConnector1, 2));
        assertTrue(registry.isApprovedConnector(testConnector1, 3));
        assertEq(registry.getLatestConnectorVersion(testConnector1), 3);

        registry.deactivateConnector(testConnector1, 2);
        assertTrue(registry.isApprovedConnector(testConnector1, 1));
        assertFalse(registry.isApprovedConnector(testConnector1, 2));
        assertTrue(registry.isApprovedConnector(testConnector1, 3));
    }
}
