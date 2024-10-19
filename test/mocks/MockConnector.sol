// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

contract MockConnector {
    uint256 public lastValue;
    bool public shouldRevert;
    address public immutable connectorPlugin;

    error UnauthorizedCaller();

    constructor(address _connectorPlugin) {
        shouldRevert = false;
        connectorPlugin = _connectorPlugin;
    }

    modifier onlyConnectorPlugin() {
        if (msg.sender != connectorPlugin) revert UnauthorizedCaller();
        _;
    }

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function execute(bytes calldata data) external onlyConnectorPlugin returns (bytes memory) {
        (bytes4 selector, bytes memory params) = abi.decode(data[:4], (bytes4, bytes));

        if (selector == this.mockFunction.selector) {
            uint256 value = abi.decode(params, (uint256));
            uint256 result = mockFunction(value);
            return abi.encode(result);
        } else if (selector == this.mockFailingFunction.selector) {
            mockFailingFunction();
        }

        revert("MockConnector: Invalid function selector");
    }

    function mockFunction(uint256 value) internal returns (uint256) {
        if (shouldRevert) {
            revert("MockConnector: Intentional failure");
        }
        lastValue = value;
        return value;
    }

    function mockFailingFunction() internal pure {
        revert("MockConnector: Intentional failure");
    }
}
