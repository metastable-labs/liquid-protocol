// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IConnector {
    function getName() external pure returns (string memory);
    function getVersion() external pure returns (uint256);
    function execute(bytes calldata data) external payable returns (bytes memory);
}
