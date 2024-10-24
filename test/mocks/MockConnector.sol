// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

contract MockConnector {
    uint256 public lastValue;
    address public lastCaller;
    bool public shouldRevert;
    uint256 public ethToReturn;

    constructor() {
        shouldRevert = false;
        ethToReturn = 0;
    }

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function setEthToReturn(uint256 _ethToReturn) external {
        ethToReturn = _ethToReturn;
    }

    function mockFunction(uint256 value) external payable returns (uint256) {
        if (shouldRevert) {
            revert("MockConnector: Intentional failure");
        }


        lastValue = value;

        // Return ETH if set
        if (ethToReturn > 0) {
            payable(address(this)).transfer(ethToReturn);
        }

        return value;
    }

    function mockFailingFunction() external pure {
        revert("MockConnector: Intentional failure");
    }

    receive() external payable {}
}
