// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IConnector {
    function getName() external view returns (string memory);
    function getVersion() external view returns (uint256);
    function execute(bytes calldata data) external payable returns (bytes memory);
    function execute(bytes calldata data, address caller) external payable returns (bytes memory);
}
