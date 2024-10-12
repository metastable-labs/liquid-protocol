# Liquid Protocol

A protocol for Liquidity and best yield aggregation.

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
```

### Deployed Addresses

| Contract | Network | Address |
|----------|---------|---------|
| AerodromeConnector | Base | [`0xaab8909B149Dd3e0DAcd2e46E846EAe75070EF47`](https://basescan.org/address/0xaab8909B149Dd3e0DAcd2e46E846EAe75070EF47) |
| ConnectorPlugin | Base | [`0x2f9a3fb2D6666A062148784DC04bC9273E017366`](https://basescan.org/address/0x2f9a3fb2D6666A062148784DC04bC9273E017366) |
| ConnectorRegistry | Base | [`0x03189a1286AF104A2bfDf980B92C152B8CE3CaAd`](https://basescan.org/address/0x03189a1286AF104A2bfDf980B92C152B8CE3CaAd) |