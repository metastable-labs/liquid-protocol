// SPDX-License-Identifier: GNU
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./interface/IOracle.sol";
import "../protocols/common/constant.sol";

contract Oracle is Constants {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The Chainlink sequencer is down.
    error SequencerDown();

    /// @dev The grace period has NOT passed after the sequencer is back up.
    error GracePeriodNotOver();

    /// @dev The datafeed is address zero.
    error InvalidDataFeed();

    /// @dev The price of a token in USD is zero.
    error InvalidPriceInUsd();

    /**
     * @notice function to get the price of token in USD
     * @param _amount token amount to calculate in USD
     * @param _token the addreas of the token
     */
    function getPriceInUSD(uint256 _amount, address _token) public view returns (uint256) {
        address _dataFeed;

        if (_token == CBBTC) _dataFeed = CBBTC_USD;
        if (_token == ETH) _dataFeed = ETH_USD;
        if (_token == USDC) _dataFeed = USDC_USD;
        if (_token == DAI) _dataFeed = DAI_USD;

        if (_dataFeed == address(0)) revert InvalidDataFeed();

        int256 priceInUSD = getLatestAnswer(SEQUENCER_UPTIME_FEED, _dataFeed);

        if (priceInUSD <= int256(0)) revert InvalidPriceInUsd();

        return (uint256(priceInUSD) * _amount) / 10 ** ERC20(_token).decimals(); // returns usd value scaled to 8 decimal
    }

    /**
     * @notice function to get the price of token in USD
     * @param _sequencerUptimeFeed uptime feed address on base network
     * @param _dataFeed data feed address on base network
     */
    function getLatestAnswer(address _sequencerUptimeFeed, address _dataFeed) public view returns (int256) {
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

        return price; // returns usd value scaled to 8 decimal
    }

    /**
     * @dev Calculates the price of 1 tokenA in terms of tokenB, normalizing decimal differences.
     * @param tokenAPriceInUsd The price of 1 tokenA in USD.
     * @param tokenAPriceDecimals The number of decimals in the tokenA price.
     * @param tokenBPriceInUsd The price of 1 tokenB in USD.
     * @param tokenBPriceDecimals The number of decimals in the tokenB price.
     */
    function getTokenAPriceInTokenB(
        uint256 tokenAPriceInUsd,
        uint8 tokenAPriceDecimals,
        uint256 tokenBPriceInUsd,
        uint8 tokenBPriceDecimals
    ) public pure returns (uint256) {
        require(tokenAPriceInUsd > 0, "tokenA price must be greater than zero");
        require(tokenBPriceInUsd > 0, "tokenB price must be greater than zero");

        // Normalize to the same decimal scale
        if (tokenAPriceDecimals > tokenBPriceDecimals) {
            tokenBPriceInUsd *= 10 ** (tokenAPriceDecimals - tokenBPriceDecimals);
        } else if (tokenBPriceDecimals > tokenAPriceDecimals) {
            tokenAPriceInUsd *= 10 ** (tokenBPriceDecimals - tokenAPriceDecimals);
        }

        // Calculate price: (tokenA / tokenB)
        return (tokenAPriceInUsd * 1e18) / tokenBPriceInUsd; // Returns result scaled to 18 decimals
    }
}
