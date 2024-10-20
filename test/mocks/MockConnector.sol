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
        if (shouldRevert) {
            revert("MockConnector: Intentional failure");
        }

        (bytes4 selector, bytes memory params) = abi.decode(data[:4], (bytes4, bytes));

        if (selector == this.mockFunction.selector) {
            uint256 value = abi.decode(params, (uint256));
            lastValue = value;
            return abi.encode(value);
        } else if (selector == this.mockFailingFunction.selector) {
            revert("MockConnector: Intentional failure");
        }

        revert("MockConnector: Invalid function selector");
    }

    function mockFunction(uint256 value) external view returns (uint256) {
        return value;
    }

    function mockFailingFunction() external pure {
        revert("MockConnector: Intentional failure");
    }
}
