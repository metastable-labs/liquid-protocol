// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IConnector {
    /// @notice Core actions that a protocol can perform
    enum ActionType {
        SUPPLY, // Supply assets
        WITHDRAW, // Withdraw assets
        BORROW, // Borrow assets
        REPAY, // Repay debt
        STAKE, // Stake assets
        UNSTAKE, // Unstake assets
        SWAP, // Swap assets
        CLAIM // Claim rewards

    }

    enum ConnectorType {
        LENDING,
        DEX,
        YIELD
    }

    function getConnectorName() external view returns (bytes32);
    function getConnectorType() external view returns (ConnectorType);

    /// @notice Standard action execution interface
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
        returns (
            address protocol,
            address[] memory assets,
            uint256[] memory assetsAmount,
            address shareToken,
            uint256 shareAmount,
            address[] memory underlyingTokens,
            uint256[] memory underlyingAmounts
        );

    /// @notice Initially updates the user token balance
    function initialTokenBalanceUpdate(bytes32 strategyId, address userAddress, address token, uint256 amount)
        external;

    /// @notice Withdraw user asset
    function withdrawAsset(address _user, address _token, uint256 _amount) external returns (bool);
}
