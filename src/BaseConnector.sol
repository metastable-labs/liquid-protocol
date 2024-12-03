// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "./interface/IConnector.sol";

/**
 * @title BaseConnector
 * @dev Abstract contract implementing basic connector functionality.
 * This contract serves as a base for specific connector implementations.
 */
abstract contract BaseConnector is IConnectorIntegration {
    /// @notice Name of the connector
    bytes32 public immutable connectorName;

    /// @notice Type of the connector
    ConnectorType public immutable connectorType;

    /**
     * @dev Constructor to set the name and type of the connector
     * @param _connectorName Name of the connector
     */
    constructor(string memory _connectorName, ConnectorType _connectorType) {
        connectorName = keccak256(bytes(_connectorName));
        connectorType = _connectorType;
    }

    /**
     * @notice Gets the name of the connector
     * @return bytes32 The name of the connector
     */
    function getConnectorName() external view override returns (bytes32) {
        return connectorName;
    }

    /**
     * @notice gets the type of the connector
     * @return ConnectorType The type of connector
     */
    function getConnectorType() external view override returns (ConnectorType) {
        return connectorType;
    }

    /**
     * @notice Executes a function call on the connected connector
     * @dev This function must be implemented by derived contracts
     * @param actionType The Core actions that a connector can perform
     * @param data The calldata for the function call containing the parameters
     * @return result The return data from the function call
     */
    function execute(ActionType actionType, bytes calldata data)
        external
        payable
        virtual
        returns (bytes memory result);
}
