// SPDX-License-Identifier: GNU
pragma solidity ^0.8.20;

import "./interface/IOracle.sol";

contract Oracle {
    error SequencerDown();
    error GracePeriodNotOver();

    /**
     * @notice function to get the price of token in USD
     * @param _sequencerUptimeFeed uptime feed address on base network
     * @param _dataFeed data feed address on base network
     */
    function getLatestAnswer(address _sequencerUptimeFeed, address _dataFeed) internal view returns (int256) {
        (, int256 answer, uint256 startedAt,,) = IOracle(_sequencerUptimeFeed).latestRoundData();

        // Answer == 0: Sequencer is up
        // Answer == 1: Sequencer is down
        bool isSequencerUp = answer == 0;
        if (!isSequencerUp) {
            revert SequencerDown();
        }

        // Make sure the grace period has passed after the
        // sequencer is back up.
        uint256 timeSinceUp = block.timestamp - startedAt;
        if (timeSinceUp <= 3600 /* 1 hour */ ) {
            revert GracePeriodNotOver();
        }

        (, int256 price,,,) = IOracle(_dataFeed).latestRoundData();

        return price; // / 10 ** 8; // returns usd value w/o decimals
    }
}
