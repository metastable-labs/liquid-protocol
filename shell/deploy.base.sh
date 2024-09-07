#!/bin/bash

# Install Forge dependencies
forge install

# Print the initial deploying message
echo "Deploying Contracts on Base..."

source .env

export ETHERSCAN_API_KEY=$BASESCAN_API_KEY
export RPC_URL=$BASE_RPC_URL

read -p "Press enter to begin the deployment..."

forge script script/deploy.s.sol:DeployScript --rpc-url $RPC_URL --broadcast -vvvv --private-key $PRIVATE_KEY --verify --delay 15
