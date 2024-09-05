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
    bytes32 private immutable _name;

    /// @notice Version of the connector
    uint256 private immutable _version;

    /// @notice Address of the protocol this connector interacts with
    address private immutable _protocolAddress;

    /**
     * @dev Constructor to set the name, version, and protocol address of the connector
     * @param name_ Name of the connector
     * @param version_ Version of the connector
     */
    constructor(string memory name_, uint256 version_) {
        _name = keccak256(bytes(name_));
        _version = version_;
    }

    /**
     * @notice Gets the name of the connector
     * @return string The name of the connector
     */
    function getName() external view override returns (string memory) {
        return string(abi.encodePacked(_name));
    }

    /**
     * @notice Gets the version of the connector
     * @return uint256 The version of the connector
     */
    function getVersion() external view override returns (uint256) {
        return _version;
    }

    /**
     * @notice Executes a function call on the connected protocol
     * @dev This function must be implemented by derived contracts
     * @param data The calldata for the function call
     * @return bytes The return data from the function call
     */
    function execute(bytes calldata data) external payable virtual override returns (bytes memory);

    /**
     * @dev Internal function to get the function selector from calldata
     * @param data The calldata to extract the selector from
     * @return bytes4 The function selector
     */
    function _getSelector(bytes calldata data) internal pure returns (bytes4) {
        return bytes4(data[:4]);
    }
}
