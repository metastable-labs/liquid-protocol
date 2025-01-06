// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "./interface/IConnector.sol";

/**
 * @title BaseConnector
 * @dev Abstract contract implementing basic connector functionality.
 * This contract serves as a base for specific connector implementations.
 */
abstract contract BaseConnector is IConnector {
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
     */
    function execute(
        ActionType actionType,
        address[] memory assetsIn,
        uint256[] memory amounts,
        address assetOut,
        uint256 stepIndex,
        uint256 amountRatio,
        bytes32 strategyId,
        address userAddress,
        bytes calldata data
    )
        external
        payable
        virtual
        returns (
            address protocol,
            address[] memory assets,
            uint256[] memory assetsAmount,
            address shareToken,
            uint256 shareAmount,
            address[] memory underlyingTokens,
            uint256[] memory underlyingAmounts
        );
}
