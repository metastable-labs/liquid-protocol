// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import {IConnector} from "./interface/IConnector.sol";
/**
 * @title ConnectorRegistry
 * @dev Manages a registry of connectors with simple versioning for Liquid.
 * This contract allows for the addition, updating, and deactivation of connectors,
 * as well as checking the approval status of a given connector address and version.
 */

contract ConnectorRegistry is Ownable(msg.sender) {
    // Custom errors
    error ConnectorAlreadyExists(address connector, uint256 version);
    error ConnectorDoesNotExist(address connector);
    error ConnectorNotActive(address connector, uint256 version);
    error InvalidVersionUpdate(address connector, uint256 currentVersion, uint256 newVersion);
    error StatusNotChanged();
    /**
     * @dev Struct to store connector information
     * @param name Name of the connector
     * @param version Version of the connector (v1, v2, v3, etc.)
     * @param isActive Whether the connector version is currently active
     */

    struct ConnectorState {
        string name;
        uint256 version;
        bool isActive;
    }

    /// @notice Mapping of connector addresses to their versions and information
    mapping(address => ConnectorState) public connectors;

    address[] public connectorList;

    event ConnectorAdded(address indexed connector, string name, uint256 version);
    event ConnectorUpdated(address indexed connector, string name);
    event ConnectorDeactivated(address indexed connector);
    event ConnectorReactivated(address indexed connector);

    /**
     * @notice Adds a new connector version to the registry
     * @dev Only the contract owner can call this function
     * @param _connector Address of the connector to be added
     * @param _name Name of the connector
     */
    function addConnector(address _connector, string memory _name) external onlyOwner {
        if (connectors[_connector].version != 0) {
            revert ConnectorAlreadyExists(_connector, connectors[_connector].version);
        }

        uint256 version = IConnector(_connector).getVersion();

        connectors[_connector] = ConnectorState(_name, version, true);
        connectorList.push(_connector);

        emit ConnectorAdded(_connector, _name, version);
    }

    /**
     * @notice Updates an existing connector version in the registry
     * @dev Only the contract owner can call this function
     * @param _connector Address of the connector to be updated
     * @param _name New name of the connector
     */
    function updateConnectorName(address _connector, string memory _name) external onlyOwner {
        if (connectors[_connector].version == 0) {
            revert ConnectorDoesNotExist(_connector);
        }

        connectors[_connector].name = _name;
        emit ConnectorUpdated(_connector, _name);
    }

    /**
     * @notice Deactivates a connector version in the registry
     * @dev Only the contract owner can call this function
     * @param _connector Address of the connector to be deactivated
     */
    function updateConnectorStatus(address _connector, bool _status) external onlyOwner {
        if (connectors[_connector].isActive == _status) {
            revert StatusNotChanged();
        }
        if (connectors[_connector].version == 0) {
            revert ConnectorDoesNotExist(_connector);
        }

        connectors[_connector].isActive = _status;

        if (!_status) emit ConnectorDeactivated(_connector);
        else emit ConnectorReactivated(_connector);
    }

    /**
     * @notice Checks if a given connector version is approved (active)
     * @param _connector Address of the connector to check
     * @return bool True if the connector version is approved (active), false otherwise
     */
    function isApprovedConnector(address _connector) external view returns (bool) {
        return connectors[_connector].isActive;
    }

    /// @notice Returns the number of connectors in the registry
    function getConnectorCount() public view returns (uint256) {
        return connectorList.length;
    }
}
