# Liquid Protocol

Liquid Curator is a permissionless strategy curation protocol. It introduces a new primitive for creating, managing, and executing complex DeFi strategies across multiple protocols. The protocol enables trustless strategy curation with atomic execution. It provides a framework for strategy composers to create and monetize their expertise while allowing users and AI Agents to discover, evaluate, and participate in these strategies with minimal friction.

## Architecture

The protocol consists of several key components:

### 1. Strategy Module
- **Strategy Contract**: Core contract that manages strategy creation and tracking
  - Stores strategy metadata and execution steps
  - Tracks strategy statistics and performance
  - Manages user participation records
  - Handles curator registration

### 2. Execution Engine
- **Engine Contract**: Handles atomic execution of strategy steps
  - Validates and executes multi-step strategies
  - Manages token approvals and transfers
  - Ensures atomic execution (all steps succeed or revert)
  - Updates strategy and user statistics

### 3. Protocol Connectors
- **Connector Contracts**: Protocol-specific adapters that:
  - Standardize interactions with external protocols (Morpho, Moonwell, etc.)
  - Handle protocol-specific logic and token conversions
  - Track protocol-level balances and shares
  - Report performance metrics back to the strategy module
 
### Component Diagram
[![](https://mermaid.ink/img/pako:eNp9kktvwjAMx79K5HPp-kKUakKaSo9IkwqXtRxCa0q1NkZposEQ330Z5VEOW6REf9s_O87jBAWVCBFUku93bDnPBTNjlcVackVyzUajGUuzVBkTqyNbUKkbXPfYIlt1eGWSLDlgoVVNgiWiqsUNSv8PJ5dw7GYxCYGF2ZO5rxv5MkO7ss12cr-jZ9QboN4QJfGFTfMM-wPYf8BvKKmU1D43mS7NQbnq2FLy4rMW1TXar53e9LcUk0T2LklRQU0fu9R4yGTgXfYaRflHsWt73SMndgfaG2j_XgssaFG2vC7N451-3TmoHbaYQ2RkiVuuG5VDLs4G5VpRehQFREpqtECSrnYQbXnTGUvvS_O485qbjtq7d8_FB1F7SzEmRCc4QOQGdjCZBFPP98x0grFnwdG4_bHtO14QuGHguGNvPDlb8H2p4NjBtB9O6IfuNAwtwLI2h170v68gsa0rOP8A6InBXw?type=png)](https://mermaid.live/edit#pako:eNp9kktvwjAMx79K5HPp-kKUakKaSo9IkwqXtRxCa0q1NkZposEQ330Z5VEOW6REf9s_O87jBAWVCBFUku93bDnPBTNjlcVackVyzUajGUuzVBkTqyNbUKkbXPfYIlt1eGWSLDlgoVVNgiWiqsUNSv8PJ5dw7GYxCYGF2ZO5rxv5MkO7ss12cr-jZ9QboN4QJfGFTfMM-wPYf8BvKKmU1D43mS7NQbnq2FLy4rMW1TXar53e9LcUk0T2LklRQU0fu9R4yGTgXfYaRflHsWt73SMndgfaG2j_XgssaFG2vC7N451-3TmoHbaYQ2RkiVuuG5VDLs4G5VpRehQFREpqtECSrnYQbXnTGUvvS_O485qbjtq7d8_FB1F7SzEmRCc4QOQGdjCZBFPP98x0grFnwdG4_bHtO14QuGHguGNvPDlb8H2p4NjBtB9O6IfuNAwtwLI2h170v68gsa0rOP8A6InBXw)

### Sequence Diagram / Execution Flow
[![](https://mermaid.ink/img/pako:eNptUt1rwjAQ_1fCPeypulpb3PLgi3OwwWBM3MPoS0jPWmiTLk1AJ_7vu7ZWqzWQ5D5-97sP7gBSJwgcKvx1qCS-ZCI1oogVo1MKYzOZlUJZtq7QDK0ra4TFdD_0LFWaKRzaF1oplFbfIfs02mqp89bTvnXa0Xze5eFsYZCkx3edqZvsnXYF_xZ5lpDMHsivDdIrbHXF3VbK2XKH0lm8Yc21LtmrNgyF3LLKYtna69NGEsW5qT5LH3kGELhrk7M3ZdEIaS-4zje6Jv1C64yir3K5vcfaa2NdNv3WfbrqTq2X2fSQJyCqpBVOaILXQxoUAB4UaAqRJbQ6hzokBrvFAmPgJCa4ETUOYnUkqHBWr_ZKArfGoQdGu3QLfCPyijTXVHHau7OVFuJH66ILIRX4AXbAJ-E4nM3C52Aa0PXDKPBgT-ZpNJ76QRhOnkJ_EgXR7OjBX8PgjyMPMMloTh_tsjc7f_wHVLD53g?type=png)](https://mermaid.live/edit#pako:eNptUt1rwjAQ_1fCPeypulpb3PLgi3OwwWBM3MPoS0jPWmiTLk1AJ_7vu7ZWqzWQ5D5-97sP7gBSJwgcKvx1qCS-ZCI1oogVo1MKYzOZlUJZtq7QDK0ra4TFdD_0LFWaKRzaF1oplFbfIfs02mqp89bTvnXa0Xze5eFsYZCkx3edqZvsnXYF_xZ5lpDMHsivDdIrbHXF3VbK2XKH0lm8Yc21LtmrNgyF3LLKYtna69NGEsW5qT5LH3kGELhrk7M3ZdEIaS-4zje6Jv1C64yir3K5vcfaa2NdNv3WfbrqTq2X2fSQJyCqpBVOaILXQxoUAB4UaAqRJbQ6hzokBrvFAmPgJCa4ETUOYnUkqHBWr_ZKArfGoQdGu3QLfCPyijTXVHHau7OVFuJH66ILIRX4AXbAJ-E4nM3C52Aa0PXDKPBgT-ZpNJ76QRhOnkJ_EgXR7OjBX8PgjyMPMMloTh_tsjc7f_wHVLD53g)

> ⚠️ **Warning**: This version of Liquid protocol hasn't been audited, so use it with caution for test purposes only.

## Roadmap (not in order):

 - [x] Single step strategies
 - [x] Multi-step strategy curation
 - [ ] Yield and rewards calculation
 - [ ] Onchain risk analysis
 - [ ] Simulating strategy before creation
 - [ ] Making some of the contracts upgradeable

## Get started

1. **Clone the repository**
   We recommend using [GH CLI](https://cli.github.com):

   ```sh
   gh repo clone metastable-labs/liquid-protocol ~/metastable-labs/liquid-protocol
   cd ~/metastable-labs/liquid-protocol
   ```

2. **Install Foundry**
   Make sure you have Foundry installed. If not, you can install it by following the instructions [here](https://book.getfoundry.sh/getting-started/installation).

3. **Install dependencies**
   Run the following command to install the necessary dependencies:

   ```sh
   forge update && forge install
   ```

## Deployments

### If you encounter this error:

Error: "./shell/deploy.base.sh: Permission denied"

Run this command:

```
chmod +x shell/deploy.*.sh
```

### Deploy

```
sh shell/deploy.sh --network=<NETWORK>
```

where <NETWORK> can be anything between ["base", "scroll", "mode", "op"]

### Help in deployment

```
sh shell/deploy.sh ---help
```

### Adding new network

1. Duplicate any deploy.NETWORK.sh file and name it deploy.DESIRED_NETWORK.sh
2. Add two enviornment variables to .env and .env.example file

```
DESIRED_NETWORKSCAN_API_KEY=
DESIRED_NETWORK_RPC_URL=
```

3. In the file `deploy.DESIRED_NETWORK.sh` file update the following variables

```
export ETHERSCAN_API_KEY=$DESIRED_NETWORKSCAN_API_KEY
export RPC_URL=$DESIRED_NETWORK_RPC_URL
```

4. Add the network to array of `allowed_networks` in file `deploy.sh`.
5. Run the command

```
sh shell/deploy.sh --network=DESIRED_NETWORK
``
