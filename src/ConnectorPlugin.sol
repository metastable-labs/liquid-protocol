// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "./ConnectorRegistry.sol";
import "./interface/IConnector.sol";

contract ConnectorPlugin {
    ConnectorRegistry public immutable registry;

    event ConnectorExecuted(address indexed connector, address indexed caller, bytes data, bytes result);

    error ConnectorNotApproved(address connector);
    error ConnectorExecutionFailed(address connector, bytes data);

    constructor(address _registry) {
        registry = ConnectorRegistry(_registry);
    }

    function execute(address _connector, bytes calldata _data) external payable returns (bytes memory) {
        uint256 latestVersion = registry.getLatestConnectorVersion(_connector);
        if (!registry.isApprovedConnector(_connector, latestVersion)) {
            revert ConnectorNotApproved(_connector);
        }

        // Pass the original caller (msg.sender) to the connector
        (bool success, bytes memory result) = _connector.call{value: msg.value}(abi.encodePacked(_data, msg.sender));
        if (!success) {
            revert ConnectorExecutionFailed(_connector, _data);
        }

        emit ConnectorExecuted(_connector, msg.sender, _data, result);
        return result;
    }
}
