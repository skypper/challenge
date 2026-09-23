# `centrifuge/centrifuge-starter-kit`

| | |
|---|---|
| **URL** | https://github.com/centrifuge/centrifuge-starter-kit |
| **Tier** | Official — reference extensions |
| **Language** | Solidity (Foundry) · **License** MIT |
| **Stars** | ~2 · **Last commit** 2026-01-09 |
| **Local size** | ~188 KB |

## What it is

Small, MIT-licensed **worked examples of extending the V3 core** — the practical
counterpart to the "immutable core, modular extensions" claim. Because it's MIT
rather than BUSL, it's the piece you can actually copy.

The README enumerates the extension points and links each to `protocol/src/`:
adapters, transfer hooks, hub managers, balance-sheet (spoke) managers,
valuations.

## The sample

`DepositRedeemFeeManager` — a **hub manager** that wraps
`BatchRequestManager.issueShares` / `revokeShares` to apply configurable per-pool
deposit and redeem fees by adjusting the effective share price.

```solidity
DepositRedeemFeeManager feeManager = new DepositRedeemFeeManager(hubRegistry, batchRequestManager);
hub.updateHubManager(poolId, address(feeManager), true);
feeManager.setFees(poolId, d18(0.01e18), d18(0.02e18));   // 1% deposit, 2% redeem
```

That three-line registration is the whole extension model in miniature: core
holds an interface reference that defaults to unset, and a pool opts in.

## Related

`protocol/src/managers/`, `protocol/src/hooks/`,
`documentation/docs/developer/protocol/features/modularity/`.
