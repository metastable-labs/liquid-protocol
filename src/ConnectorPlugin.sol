// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "./ConnectorRegistry.sol";
import "./interface/IConnector.sol";

/// @title ConnectorPlugin
/// @notice This contract serves as an intermediary between the smart wallet and connectors,
///         ensuring that only approved connectors are executed.
/// @dev This plugin checks the ConnectorRegistry before forwarding calls to connectors.
contract ConnectorPlugin {
    /// @notice The address of the ConnectorRegistry contract
    ConnectorRegistry public immutable registry;

    /// @notice Emitted when a connector is successfully executed
    /// @param connector The address of the executed connector
    /// @param data The calldata passed to the connector
    /// @param result The result returned by the connector
    event ConnectorExecuted(address indexed connector, bytes data, bytes result);

    /// @notice Constructs the ConnectorPlugin with a reference to the ConnectorRegistry
    /// @param _registry The address of the ConnectorRegistry contract
    constructor(address _registry) {
        registry = ConnectorRegistry(_registry);
    }

    /// @notice Executes a call to an approved connector
    /// @dev This function checks if the connector is approved before executing the call
    /// @param connector The address of the connector to execute
    /// @param data The calldata to pass to the connector
    /// @return result The bytes returned by the connector execution
    function execute(address connector, bytes calldata data) external payable returns (bytes memory result) {
        require(registry.isApprovedConnector(connector), "ConnectorPlugin: Connector not approved");

        bool success;
        (success, result) = connector.call(data);
        require(success, "ConnectorPlugin: Connector execution failed");

        emit ConnectorExecuted(connector, data, result);
    }
}
