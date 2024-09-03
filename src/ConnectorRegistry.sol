// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ConnectorRegistry
 * @dev Manages a registry of connectors for Liquid.
 * This contract allows for the addition, updating, and deactivation of connectors,
 * as well as checking the approval status of a given connector address.
 */
contract ConnectorRegistry is Ownable(msg.sender) {
    /**
     * @dev Struct to store connector information
     * @param name Name of the connector
     * @param version Version of the connector
     * @param isActive Whether the connector is currently active
     */
    struct Connector {
        string name;
        uint256 version;
        bool isActive;
    }

    /// @notice Mapping of connector addresses to their information
    mapping(address => Connector) public connectors;

    /// @notice List of all connector addresses
    address[] public connectorList;

    /**
     * @notice Emitted when a new connector is added to the registry
     * @param connector Address of the newly added connector
     * @param name Name of the connector
     * @param version Version of the connector
     */
    event ConnectorAdded(address indexed connector, string name, uint256 version);

    /**
     * @notice Emitted when a connector in the registry is updated
     * @param connector Address of the updated connector
     * @param name New name of the connector
     * @param version New version of the connector
     */
    event ConnectorUpdated(address indexed connector, string name, uint256 version);

    /**
     * @notice Emitted when a connector is deactivated
     * @param connector Address of the deactivated connector
     */
    event ConnectorDeactivated(address indexed connector);

    /**
     * @notice Adds a new connector to the registry
     * @dev Only the contract owner can call this function
     * @param _connector Address of the connector to be added
     * @param _name Name of the connector
     * @param _version Version of the connector
     */
    function addConnector(address _connector, string memory _name, uint256 _version) external onlyOwner {
        require(connectors[_connector].version == 0, "Connector already exists");
        connectors[_connector] = Connector(_name, _version, true);
        connectorList.push(_connector);
        emit ConnectorAdded(_connector, _name, _version);
    }

    /**
     * @notice Updates an existing connector in the registry
     * @dev Only the contract owner can call this function
     * @param _connector Address of the connector to be updated
     * @param _name New name of the connector
     * @param _version New version of the connector
     */
    function updateConnector(address _connector, string memory _name, uint256 _version) external onlyOwner {
        require(connectors[_connector].version > 0, "Connector does not exist");
        connectors[_connector] = Connector(_name, _version, true);
        emit ConnectorUpdated(_connector, _name, _version);
    }

    /**
     * @notice Deactivates a connector in the registry
     * @dev Only the contract owner can call this function
     * @param _connector Address of the connector to be deactivated
     */
    function deactivateConnector(address _connector) external onlyOwner {
        require(connectors[_connector].isActive, "Connector is not active");
        connectors[_connector].isActive = false;
        emit ConnectorDeactivated(_connector);
    }

    /**
     * @notice Checks if a given connector is approved (active)
     * @param _connector Address of the connector to check
     * @return bool True if the connector is approved (active), false otherwise
     */
    function isApprovedConnector(address _connector) external view returns (bool) {
        return connectors[_connector].isActive;
    }

    function getConnectorList() public view returns (address[] memory) {
        return connectorList;
    }
}
