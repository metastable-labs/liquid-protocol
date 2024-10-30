# Liquid Protocol Audit

## Executive Summary

### Intro

Juan ([0xjuaan on X](https://x.com/0xjuaan)) is an independent security researcher with top competitive audit placements.

Full audit portfolio: [https://github.com/0xjuaan](https://github.com/0xjuaan)

### Audit Details

The Liquid Protocol (by the Supermigrate team) aims to improve the DeFi user experience by leveraging smart wallets and a seamless mobile app interface.

This audit focuses on the alpha version of the Liquid Protocol, which provides tools for users to manage Aerodrome liquidity positions in **basic** Aerodrome pools (UniswapV2 styled pools). 

This audit additionally includes extensive forked integration testing, and application of fixes. 

**Scope:** [https://github.com/metastable-labs/liquid-protocol](https://github.com/metastable-labs/liquid-protocol) @ commit 6a04de

(Excluding `src/connectors/base/uniswap/`)

### Timeline

14th October - 18th October

## Finding Severity Classification

| Severity               | Impact: High | Impact: Medium | Impact: Low |
| ---------------------- | ------------ | -------------- | ----------- |
| **Likelihood: High**   | Critical     | High           | Medium      |
| **Likelihood: Medium** | High         | Medium         | Low         |
| **Likelihood: Low**    | Medium       | Low            | Low         |

### Impact

- High - leads to a significant material loss of assets in the protocol or significantly harms a group of users.

- Medium - leads to a moderate material loss of assets in the protocol or moderately harms a group of users.

- Low - leads to a minor material loss of assets in the protocol or harms a small group of users.

### Likelihood

- High - attack path is possible with reasonable assumptions that mimic on-chain conditions, and the cost of the attack is relatively low compared to the amount of funds that can be stolen or lost.

- Medium - only a conditionally incentivized attack vector, but still relatively likely.

- Low - has too many or too unlikely assumptions or requires a significant stake by the attacker with little or no incentive.

### Action required for severity levels

- Critical - Must fix as soon as possible (if already deployed)

- High - Must fix (before deployment if not already deployed)

- Medium - Should fix

- Low - Could fix

## Summary of Findings

| **ID** |                                           **Title** | **Severity** | **Status** |
| --- | --- | --- | --- |
| H-1 | Using the ConnectorPlugin will fail due to incorrect use of `msg.sender` | High | Fixed |
| M-1 | Price ratio check reverts due to incorrect assumption | Medium | Fixed |
| M-2 | Balancing token ratios will fail when `tokenB` has <18 decimals | Medium | Fixed |
| M-3 | For some basic stable pools, not all of the user’s tokens will be deposited | Medium | Fixed |
| M-4 | `AerodromeConnector.execute()` is payable but does not handle native tokens properly | Medium | Fixed |
| L-1 | There are no checks against price manipulation | Low | Fixed |
| L-2 | Each connector can’t have more than a single version | Low | Fixed |
| L-3 | `calculateAmountIn()` assumes swap fee is 0.3% | Low | Fixed |
| I-1 | Unnecessary transfer for 0 amounts | Informational | Fixed |
| I-2 | Unnecessary check in `_removeBasicLiquidity()` | Informational | Fixed |

# Findings

## [H-01] Using the ConnectorPlugin will fail due to incorrect use of `msg.sender`

### Vulnerability Description

The `ConnectorPlugin` contract is intended to be the intermediary between smart wallets and the connectors. It calls the connector:

```jsx
(bool success, bytes memory result) = _connector.call{value: msg.value}(_data);
```

However, the `AerodromeConnector` incorrectly assumes that `msg.sender` is the smart wallet, when it is actually the plugin.

This transfers leftovers to the plugin instead of the user’s smart wallet, and attempts to transfer tokens from the plugin instead of the user’s smart wallet.

### Recommendation

Have an additional `caller` parameter in the Connector.execute() function, and then replace all instances of `msg.sender`  in the `AerodromeConnector` with that parameter

The `caller` should be the smart wallet which is `msg.sender` in the context of the plugin. 

NOTE: To avoid introducing another vulnerability (users spoofing the ‘caller’ parameter by directly calling the connector, to steal approved funds), the fix would require another change- making the aerodrome connector permissioned (only allowing the plugin to call `AerodromeConnector.execute()`)

If the connectors must remain permissionless, then instead of the above fix, the plugin should be adjusted to accept funds from the user, and forward leftovers back to the user.

---

## [M-01] Price ratio check reverts due to incorrect assumption

### Vulnerability Description

`AerodromeUtils.checkPriceRatio()` does not handle the case where the user provides an unbalanced ratio of tokens. This leads to the `inputRatio` being very different to the `currentRatio`  causing a revert.

### Recommendation

An alternative and more effective way to check price impact for volatile pairs would be to check the reserve ratio before `balanceTokenRatio` and compare it with the reserve ratio after `balanceTokenRatio`

Such an implementation also allows for adding liquidity to low liquidity pools in cases where no token ratio balancing is needed (which would not be available before)

If the deviation is more than a given `MAX_PRICE_IMPACT` (or a parameter provided by the user), then revert

---

## [M-02] Balancing token ratios will fail when tokenB has <18 decimals

### Vulnerability Description

The tokens to sell are calculated in the following way when selling token B:

```solidity
tokensToSell = calculateAmountIn(y, x, b, a, bDecMultiplier, aDecMultiplier) 
							/ bDecMultiplier;
```

The dividing by the multiplier is unnecessary because that is already implemented in the `calculateAmountIn()` function:

```solidity
return amountIn / aDec;
```

This causes the `tokensToSell` to be scaled down to 0, causing a revert in the following swap.

### Proof of Concept

The following test reverts due to calculating `tokensToSell` incorrectly

```solidity
function test_incorrectMath_causesRevert() public {
    uint256 amountADesired = 0;
    uint256 amountBDesired = 1e9; // 1000 USDC. Some should get swapped to WETH
    uint256 amountAMin = 900 * 1e6;
    uint256 amountBMin = 0.9 ether;
    bool stable = false;
    uint256 deadline = block.timestamp + 1 hours;

    vm.startPrank(ALICE);

    bytes memory data = abi.encodeWithSelector(
        IRouter.addLiquidity.selector,
        WETH,
        USDC,
        stable,
        amountADesired,
        amountBDesired,
        amountAMin,
        amountBMin,
        ALICE,
        deadline
    );

    bytes memory result = connector.execute(data);
    vm.stopPrank();
}
```

### Recommendation

The following change will fix the issue:

```diff
-tokensToSell = calculateAmountIn(y, x, b, a, bDecMultiplier, aDecMultiplier) 
-							/ bDecMultiplier;
+tokensToSell = calculateAmountIn(y, x, b, a, bDecMultiplier, aDecMultiplier); 
```

---

## [M-03] For some basic stable pools, not all of the user’s tokens will be deposited

### Description

The `DOLA/USDC` basic stable pool has unequal reserves, (~$63M of DOLA, ~$45M of USDC) even though the price when swapping is 1:1. 

Balancing token ratios does not take this into account, and it leads to a lot of funds being left over, and sent back to the user.

This is due to stable pools using a different curve invariant $x^3y + y^3x \geq k$

### Proof of Concept

- Foundry test
    
    ```solidity
    function test_dola_addLiquidity() public {
            uint256 amountADesired = 1000e6;
            uint256 amountBDesired = 0;
            uint256 amountAMin = 0;
            uint256 amountBMin = 0;
            bool stable = true;
            uint256 deadline = block.timestamp + 1 hours;
    
            vm.startPrank(ALICE);
    
            //console.log("USDC balance before: %s", IERC20(USDC).balanceOf(ALICE));
            //console.log("AERO balance before: %s", IERC20(WETH).balanceOf(ALICE));
    
            bytes memory data = abi.encodeWithSelector(
                IRouter.addLiquidity.selector,
                USDC,
                DOLA,
                stable,
                amountADesired,
                amountBDesired,
                amountAMin,
                amountBMin,
                ALICE,
                deadline
            );
    
            address pool = IPoolFactory(AERODROME_FACTORY).getPool(USDC, DOLA, stable);
    
            console.log("Liquidity balance of Alice before deposit: %e", IERC20(pool).balanceOf(ALICE));
    
            bytes memory result = connector.execute(data);
            (uint256 amountA, uint256 amountB, uint256 liquidity) = abi.decode(result, (uint256, uint256, uint256));
    
            console.log("Liquidity added: %e USDC, %e DOLA", amountA, amountB);
    
            assertGt(amountA, 0, "Amount A should be greater than 0");
            assertGt(amountB, 0, "Amount B should be greater than 0");
            assertGt(liquidity, 0, "Liquidity should be greater than 0");
    
            console.log("Liquidity balance of Alice after deposit: %e", IERC20(pool).balanceOf(ALICE));
            vm.stopPrank();
        }
    ```
    

Run the above foundry test, with the following console log at the end of `_depositBasicLiquidity()`:

```diff
+console.log("Sending leftovers: %e tokenA and %e tokenB", leftoverA, leftoverB);
AerodromeUtils.returnLeftovers(tokenA, tokenB, leftoverA, leftoverB, msg.sender, WETH_ADDRESS);
```

The output is:

`Sending leftovers: 1.40200504e8 tokenA and 0e0 tokenB`

That is $140 leftover which is returned to the user, when attempting to deposit $1000. 

Note that `AerodromeUtils.checkPriceRatio()` will have to be removed for the test to work, since it causes incorrect reverts

### Recommendation

Since the invariant cannot be solved analytically, one way to resolve this issue is to repeat the balanceTokenRatio+addLiquidity action multiple times, until the residual amount is low enough. Here is a tested sample of the changes that can be made:

```diff
@@ -166,15 +175,53 @@ contract AerodromeConnector is BaseConnector, Constants, AerodromeEvents {
         if (pool == address(0)) revert("Pool does not exist");
 
         // Add liquidity to the basic pool
+        uint256 leftoverA = amountADesired;
+        uint256 leftoverB = amountBDesired;
+
         (amountAOut, amountBOut, liquidity) = aerodromeRouter.addLiquidity(
             tokenA, tokenB, stable, amountADesired, amountBDesired, amountAMin, amountBMin, to, deadline
         );
 
         if (liquidity == 0) revert InsufficientLiquidity();
 
-        uint256 leftoverA = amountADesired - amountAOut;
-        uint256 leftoverB = amountBDesired - amountBOut;
-
+        leftoverA -= amountAOut;
+        leftoverB -= amountBOut;
+        
+
+        if (stable) {
+            for (uint i = 0; i < 3; i++) {
+                // Balance token ratio before depositing
+                (uint256[] memory amounts2, bool sellTokenA2) = AerodromeUtils.balanceTokenRatio(
+                    tokenA, tokenB, leftoverA, leftoverB, stable, address(aerodromeRouter)
+                );
+
+                // Update token amounts after swaps
+                if (sellTokenA2) {
+                    leftoverA -= amounts2[0];
+                    leftoverB += amounts2[1];
+                } else {
+                    leftoverB -= amounts2[0];
+                    leftoverA += amounts2[1];
+                }
+
+                // Add liquidity to the basic pool
+                (amountAOut, amountBOut, liquidity) = aerodromeRouter.addLiquidity(
+                    tokenA, tokenB, stable, leftoverA, leftoverB, 0, 0, to, deadline
+                );
+
+                leftoverA -= amountAOut;
+                leftoverB -= amountBOut;
+
+                if (liquidity == 0) break;
+            }
+
+        }      
+
         AerodromeUtils.returnLeftovers(tokenA, tokenB, leftoverA, leftoverB, msg.sender, WETH_ADDRESS);
 
         emit LiquidityAdded(tokenA, tokenB, amountAOut, amountBOut, liquidity);

```

After making the change, running the same PoC yields the following output:

`Sending leftovers: 3.8636e5 tokenA and 0e0 tokenB`

This is $0.39 left over, after repeating the balanceTokenRatio+addLiquidity action 3 additional times

### Alternate fix:

Using the following equation within `calculateAmountIn()` to determine the tokens to sell (for stable pools only) leads to much lower loss:

```solidity
// Obtain intermediate terms
uint256 xy = (y * x) / WAD;
uint256 bx = (b * x) / WAD;
uint256 ay = (y * a) / WAD;

if (stable) {
    return (ay - bx) * WAD / (y + x) / aDec;
}
```

---

## [M-04] AerodromeConnector.execute() is payable but does not handle native tokens properly

### Vulnerability Description

The `execute()`  function is payable and accepts native tokens, but they are not handled. 

There is no way for users to perform actions in the connector using native ETH. They would have to wrap the ETH to WETH in a previous call.

### Recommendation

Consider assuming that if `token0` or `token1` in the encoded parameters is `address(0)`, then `msg.value` needs to be wrapped into WETH and then update `token0` or `token1`  to the address of WETH.

Alternatively, if `token0` or `token1` is WETH, and `msg.value > 0`, then assume that they have provided that token in native form and it should be wrapped to WETH first. 

---

## [L-01] There are no checks against price manipulation

### Vulnerability Description

While `AerodromeUtils.checkPriceRatio()` checks that the price impact of swapping in the pool is not large, there are no checks to prevent price manipulation.

Price manipulation can occur when liquidity is being added to aerodrome via a connector, and one user is adding the liquidity on behalf of other users. This can occur in future use cases of the connector, like if the connector is used for liquidity migration between chains, or if it is used by vault curators who manage funds of many users.

In such cases, a malicious actor can manipulate the price before the liquidity is deposited, causing it to be deposited at an unfavourable price. The attacker can then swap in the opposite direction to earn profit from this incorrectly priced liquidity, stealing from users.

### Recommendation

There are two potential solutions:

- Add checks within `_depositBasicLiquidity()` to check the spot price against a TWAP oracle.
- Add documentation to ensure that future developments that use connectors will ensure to implement such checks in their systems.

---

## [L-02] Each connector can’t have more than a single version

### Description

The `ConnectorRegistry` aims to store multiple different versions of a given `connector`  address, accessed via the indexing `connectors[_connector][_version]`

The issue is that since the connectors are not upgradeable, each address can only correspond to a single version.

### Recommendation

Redesign the data structures in the registry

---

## [L-03] balanceTokenRatio assumes swapFee is 0.3%

### Description

The formula used in `calculateAmountIn()` when balancing token ratios assumes that the swap fee is 0.3%. However there are many basic volatile pools which have a fee of 1%, [here](https://aerodrome.finance/deposit?token0=0x4200000000000000000000000000000000000006&token1=0x940181a94A35A4569E4529A3CDfB74e38FD98631&type=-1) is an example. In that case, `calculateAmountIn()`  returns a slightly incorrect value leading to increased leftovers which are not deposited into the pool.

### Recommendation

Add a conditional branch for when `swapFee` is equal to 100 basis points. The following simultaneous equation will need to be solved again (to calculate `tokensToSell`) using the new `fee` of 100 bips:

1. $\frac{amountA -tokensToSell}{amountB+tokensReceived} = \frac{reserveA+tokensToSell}{reserveB-tokensReceived}$
2. $tokensReceived = \frac{tokensToSell * reserveB * (10000 - fee)}{10000*x + (10000-fee)*tokensToSell}$

---

## [I-01] Unnecessary transfer for 0 amounts

### Description

In `_depositBasicLiquidity()` , it transfers tokens from the caller even though the amount can sometimes be `0` (when the user provides one token and the ratio needs to be balanced later)

This can revert for some non-standard ERC20s, and in general is an unnecessary call when the value is zero.

### Recommendation

Change these lines: https://github.com/metastable-labs/liquid-protocol/blob/6a04de333beadbc6a286491864526c8d358b8847/src/connectors/base/aerodrome/main.sol#L126-L127

```diff
-IERC20(tokenA).transferFrom(caller, address(this), amountADesired);
-IERC20(tokenB).transferFrom(caller, address(this), amountBDesired);

+if (amountADesired > 0) IERC20(tokenA).transferFrom(caller, address(this), amountADesired);
+if (amountBDesired > 0) IERC20(tokenB).transferFrom(caller, address(this), amountBDesired);
```

## [I-02] Unnecessary check in _removeBasicLiquidity

### Description

```solidity
(amountA, amountB) =
    aerodromeRouter.removeLiquidity(tokenA, tokenB, stable, liquidity, amountAMin, amountBMin, to, deadline);

if (amountA < amountAMin || amountB < amountBMin) {
    revert SlippageExceeded(); 
}
```

The above slippage check is unnecessary because the `amountAMin` and `amountBMin` parameters are passed in to `aerodromeRouter.removeLiquidity()`, and the same parameters are checked within that function:

```solidity
if (amountA < amountAMin) revert InsufficientAmountA();
if (amountB < amountBMin) revert InsufficientAmountB();
```

### Recommendation

The check can be safely removed
