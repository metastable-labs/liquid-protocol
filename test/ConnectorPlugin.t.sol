// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "forge-std/Test.sol";
import "../src/ConnectorPlugin.sol";
import "../src/ConnectorRegistry.sol";
import "./mocks/MockConnector.sol";

contract ConnectorPluginTest is Test {
    ConnectorPlugin public plugin;
    ConnectorRegistry public registry;
    MockConnector public approvedConnector;
    MockConnector public unapprovedConnector;
    address public owner;
    address public constant ALICE = address(0x1);

    function setUp() public {
        owner = address(this);
        registry = new ConnectorRegistry();
        plugin = new ConnectorPlugin(address(registry));
        approvedConnector = new MockConnector();
        unapprovedConnector = new MockConnector();

        registry.addConnector(address(approvedConnector), "ApprovedConnector", 1);
    }

    function testExecuteApprovedConnector() public {
        bytes memory data = abi.encodeWithSignature("mockFunction(uint256)", 42);
        vm.prank(ALICE);
        bytes memory result = plugin.execute(address(approvedConnector), data);
        (uint256 returnedValue, address caller) = abi.decode(result, (uint256, address));
        assertEq(returnedValue, 42);
        assertEq(caller, ALICE);
    }

    function testExecuteUnapprovedConnector() public {
        bytes memory data = abi.encodeWithSignature("mockFunction(uint256)", 42);
        vm.prank(ALICE);
        vm.expectRevert(
            abi.encodeWithSelector(ConnectorPlugin.ConnectorNotApproved.selector, address(unapprovedConnector))
        );
        plugin.execute(address(unapprovedConnector), data);
    }

    function testExecuteFailedConnectorCall() public {
        bytes memory data = abi.encodeWithSignature("mockFailingFunction()");
        vm.prank(ALICE);
        vm.expectRevert(
            abi.encodeWithSelector(ConnectorPlugin.ConnectorExecutionFailed.selector, address(approvedConnector), data)
        );
        plugin.execute(address(approvedConnector), data);
    }

    function testExecuteNonExistentFunction() public {
        bytes memory data = abi.encodeWithSignature("nonExistentFunction()");
        vm.prank(ALICE);
        vm.expectRevert(
            abi.encodeWithSelector(ConnectorPlugin.ConnectorExecutionFailed.selector, address(approvedConnector), data)
        );
        plugin.execute(address(approvedConnector), data);
    }

    function testEmitsConnectorExecutedEvent() public {
        bytes memory data = abi.encodeWithSignature("mockFunction(uint256)", 42);

        vm.expectEmit(true, true, false, true);
        emit ConnectorPlugin.ConnectorExecuted(address(approvedConnector), ALICE, data, abi.encode(42, ALICE));

        vm.prank(ALICE);
        plugin.execute(address(approvedConnector), data);
    }

    function testExecuteWithRevertFlag() public {
        approvedConnector.setShouldRevert(true);
        bytes memory data = abi.encodeWithSignature("mockFunction(uint256)", 42);
        vm.prank(ALICE);
        vm.expectRevert(
            abi.encodeWithSelector(ConnectorPlugin.ConnectorExecutionFailed.selector, address(approvedConnector), data)
        );
        plugin.execute(address(approvedConnector), data);
    }

    function testLeftoverEthReturnedToOriginalCaller() public {
        // Setup: Make the connector return some ETH
        approvedConnector.setEthToReturn(1 ether);

        bytes memory data = abi.encodeWithSignature("mockFunction(uint256)", 42);
        uint256 initialBalance = ALICE.balance;

        vm.prank(ALICE);
        plugin.execute{value: 2 ether}(address(approvedConnector), data);

        assertEq(ALICE.balance, initialBalance + 1 ether, "Leftover ETH should be returned to ALICE");
    }

    receive() external payable {}
}
