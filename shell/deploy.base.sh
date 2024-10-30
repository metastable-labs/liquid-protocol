#!/bin/bash

# Install Forge dependencies
forge install

# Print the initial deploying message
echo "Deploying Contracts on Base..."

source .env

export ETHERSCAN_API_KEY=$BASESCAN_API_KEY
export RPC_URL=$BASE_RPC_URL
export DEPLOYER_PUB=$DEPLOYER_PUB

read -p "Press enter to begin the deployment..."

forge script script/deploy.s.sol:DeployScript --rpc-url $RPC_URL --account liquid-deployment --sender $DEPLOYER_PUB --broadcast -vvvv --verify --delay 15
