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

    // Custom errors
    error ConnectorNotApproved(address connector);
    error ConnectorExecutionFailed(address connector, bytes data);

    /// @notice Constructs the ConnectorPlugin with a reference to the ConnectorRegistry
    /// @param _registry The address of the ConnectorRegistry contract
    constructor(address _registry) {
        registry = ConnectorRegistry(_registry);
    }

    function execute(address _connector, bytes calldata _data) external payable returns (bytes memory) {
        uint256 latestVersion = registry.getLatestConnectorVersion(_connector);
        if (!registry.isApprovedConnector(_connector, latestVersion)) {
            revert ConnectorNotApproved(_connector);
        }

        (bool success, bytes memory result) = _connector.call{value: msg.value}(_data);
        if (!success) {
            revert ConnectorExecutionFailed(_connector, _data);
        }

        emit ConnectorExecuted(_connector, _data, result);
        return result;
    }
}
