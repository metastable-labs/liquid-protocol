#!/bin/bash

# Function to show help message
function show_help {
    echo "Usage: $0 --network=<network_name>"
    echo "Run deployment script for a specific network."
    echo
    echo "Options:"
    echo "  --network=<network_name>  Specify the network to deploy. Choose from: ${allowed_networks[*]}"
    echo "  --help                    Show this help message."
}

# Define allowed networks
allowed_networks=("base")

# Check if no parameters were provided or help is requested
if [ $# -eq 0 ] || [[ "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Check for correct usage
if [[ "$1" != --network=* ]]; then
    echo "Error: Incorrect usage."
    show_help
    exit 1
fi

# Extract network value from the first argument
network=$(echo "$1" | cut -d '=' -f 2)

# Function to check if the network is in the allowed list
function is_allowed_network {
    local network=$1
    for n in "${allowed_networks[@]}"; do
        if [[ "$n" == "$network" ]]; then
            return 0
        fi
    done
    return 1
}

# Validate network and run the corresponding script
if is_allowed_network "$network"; then
    script_name="deploy.$network.sh"
    if [ -f "shell/$script_name" ]; then
        echo "Running script for network: $network"
        "./shell/$script_name"
    else
        echo "Error: Script file $script_name does not exist."
        exit 1
    fi
else
    echo "Error: Invalid network. Allowed networks are: ${allowed_networks[*]}"
    show_help
    exit 1
fi
