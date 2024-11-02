#!/bin/bash

# Install Forge dependencies
forge install

# Print the initial deploying message
echo "Deploying Contracts on Base..."

source .env

export ETHERSCAN_API_KEY=$BASESCAN_API_KEY
export RPC_URL=$BASE_RPC_URL
export ACCOUNT_NAME=$ACCOUNT_NAME 

read -p "Press enter to begin the deployment..."

# Import wallet interactively if not already imported
cast wallet list | grep -q "$ACCOUNT_NAME" || cast wallet import "$ACCOUNT_NAME" --interactive

# Retrieve wallet address
SENDER_ADDRESS=$(cast wallet address --account "$ACCOUNT_NAME")

# Deploy
forge script script/contracts.s.sol:ContractDeploymentScript --rpc-url $RPC_URL --account "$ACCOUNT_NAME" --sender "$SENDER_ADDRESS" --broadcast -vvvv --verify --delay 15
