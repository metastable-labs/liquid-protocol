// SPDX-License-Identifier: GNU
pragma solidity ^0.8.20;

import "../../src/interface/IConnector.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockConnector is IConnector {
    function execute(
        ActionType actionType,
        address[] memory assetsIn,
        uint256[] memory amounts,
        address assetOut,
        uint256 stepIndex,
        uint256 amountRatio,
        bytes32 strategyId,
        address user,
        bytes memory data
    )
        external
        payable
        returns (
            address protocol,
            address[] memory assets,
            uint256[] memory assetsAmount,
            address shareToken,
            uint256 shareAmount,
            address[] memory underlyingTokens,
            uint256[] memory underlyingAmounts
        )
    {
        // Mock successful execution
        assets = assetsIn;
        assetsAmount = amounts;
        protocol = address(this);
        shareToken = address(0);
        shareAmount = 0;
        underlyingTokens = assetsIn;
        underlyingAmounts = amounts;
        return (protocol, assets, assetsAmount, shareToken, shareAmount, underlyingTokens, underlyingAmounts);
    }

    function getConnectorType() external pure returns (ConnectorType) {
        return ConnectorType.LENDING;
    }

    function getConnectorName() external pure returns (bytes32) {
        return bytes32("MockConnector");
    }

    function initialTokenBalanceUpdate(bytes32 strategyId, address user, address token, uint256 amount) external {}

    function withdrawAsset(address _user, address _token, uint256 _amount) external returns (bool) {
        IERC20(_token).transfer(_user, _amount);
        return true;
    }
}
