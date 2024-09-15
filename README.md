## Liquid Protocol
A protocol for Liquidity and best yield aggregation.

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
