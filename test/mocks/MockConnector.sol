// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

contract MockConnector {
    uint256 public lastValue;
    bool public shouldRevert;

    constructor() {
        shouldRevert = false;
    }

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function mockFunction(uint256 value) external returns (uint256) {
        if (shouldRevert) {
            revert("MockConnector: Intentional failure");
        }
        lastValue = value;
        return value;
    }

    function mockFailingFunction() external pure {
        revert("MockConnector: Intentional failure");
    }
}
