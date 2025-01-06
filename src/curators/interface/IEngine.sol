// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IEngine {
    function join(bytes32 _strategyId, address _strategyModule, uint256[] memory _amounts) external;
}
