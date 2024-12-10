// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IOracle {
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

    function getLatestAnswer(address _sequencerUptimeFeed, address _dataFeed) external view returns (int256);

    function getTokenAPriceInTokenB(
        uint256 tokenAPriceInUsd,
        uint8 tokenAPriceDecimals,
        uint256 tokenBPriceInUsd,
        uint8 tokenBPriceDecimals
    ) external pure returns (uint256);
}
