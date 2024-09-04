// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ConnectorRegistry
 * @dev Manages a registry of connectors with simple versioning for Liquid.
 * This contract allows for the addition, updating, and deactivation of connectors,
 * as well as checking the approval status of a given connector address and version.
 */
contract ConnectorRegistry is Ownable(msg.sender) {
    // Custom errors
    error ConnectorAlreadyExists(address connector, uint256 version);
    error ConnectorVersionDoesNotExist(address connector, uint256 version);
    error ConnectorNotActive(address connector, uint256 version);
    error InvalidVersionUpdate(address connector, uint256 currentVersion, uint256 newVersion);

    /**
     * @dev Struct to store connector information
     * @param name Name of the connector
     * @param version Version of the connector (v1, v2, v3, etc.)
     * @param isActive Whether the connector version is currently active
     */
    struct Connector {
        string name;
        uint256 version;
        bool isActive;
    }

    /// @notice Mapping of connector addresses to their versions and information
    mapping(address => mapping(uint256 => Connector)) public connectors;

    /// @notice List of all connector addresses
    address[] public connectorList;

    /// @notice Mapping to store the latest version for each connector
    mapping(address => uint256) public latestVersion;

    event ConnectorAdded(address indexed connector, string name, uint256 version);
    event ConnectorUpdated(address indexed connector, string name, uint256 version);
    event ConnectorDeactivated(address indexed connector, uint256 version);

    /**
     * @notice Adds a new connector version to the registry
     * @dev Only the contract owner can call this function
     * @param _connector Address of the connector to be added
     * @param _name Name of the connector
     * @param _version Version of the connector (should be greater than the current latest version)
     */
    function addConnector(address _connector, string memory _name, uint256 _version) external onlyOwner {
        if (connectors[_connector][_version].version != 0) {
            revert ConnectorAlreadyExists(_connector, _version);
        }
        if (_version <= latestVersion[_connector]) {
            revert InvalidVersionUpdate(_connector, latestVersion[_connector], _version);
        }
        connectors[_connector][_version] = Connector(_name, _version, true);
        latestVersion[_connector] = _version;

        if (latestVersion[_connector] == _version) {
            bool connectorExists = false;
            for (uint256 i = 0; i < connectorList.length; i++) {
                if (connectorList[i] == _connector) {
                    connectorExists = true;
                    break;
                }
            }
            if (!connectorExists) {
                connectorList.push(_connector);
            }
        }

        emit ConnectorAdded(_connector, _name, _version);
    }

    /**
     * @notice Updates an existing connector version in the registry
     * @dev Only the contract owner can call this function
     * @param _connector Address of the connector to be updated
     * @param _name New name of the connector
     * @param _version Version of the connector to update
     */
    function updateConnector(address _connector, string memory _name, uint256 _version) external onlyOwner {
        if (connectors[_connector][_version].version == 0) {
            revert ConnectorVersionDoesNotExist(_connector, _version);
        }
        connectors[_connector][_version].name = _name;
        connectors[_connector][_version].isActive = true;

        emit ConnectorUpdated(_connector, _name, _version);
    }

    /**
     * @notice Deactivates a connector version in the registry
     * @dev Only the contract owner can call this function
     * @param _connector Address of the connector to be deactivated
     * @param _version Version of the connector to deactivate
     */
    function deactivateConnector(address _connector, uint256 _version) external onlyOwner {
        if (!connectors[_connector][_version].isActive) {
            revert ConnectorNotActive(_connector, _version);
        }
        connectors[_connector][_version].isActive = false;
        emit ConnectorDeactivated(_connector, _version);
    }

    /**
     * @notice Checks if a given connector version is approved (active)
     * @param _connector Address of the connector to check
     * @param _version Version of the connector to check
     * @return bool True if the connector version is approved (active), false otherwise
     */
    function isApprovedConnector(address _connector, uint256 _version) external view returns (bool) {
        return connectors[_connector][_version].isActive;
    }

    /**
     * @notice Gets the latest version of a connector
     * @param _connector Address of the connector
     * @return uint256 The latest version number of the connector
     */
    function getLatestConnectorVersion(address _connector) external view returns (uint256) {
        return latestVersion[_connector];
    }

    /// @notice Returns the number of connectors in the registry
    function getConnectorCount() public view returns (uint256) {
        return connectorList.length;
    }
}
