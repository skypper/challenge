# `centrifuge/passthrough-vaults`

| | |
|---|---|
| **URL** | https://github.com/centrifuge/passthrough-vaults |
| **Tier** | Official — V3 satellite |
| **Language** | Solidity (Foundry) · **License** BUSL 1.1 |
| **Stars** | ~1 · **Last commit** 2026-07-20 |
| **Local size** | ~2.2 MB |

## What it is

A **fully immutable, non-custodial** wrapper that lets many investors share a
single seat in an underlying Centrifuge vault. Requests are forwarded straight
through and settled FIFO; investors receive the real share token; the passthrough
never holds funds on anyone's behalf. No admin, no upgrade, no owner.

Its point: because the passthrough is the *sole* participant in the underlying
vault, it can enforce **its own investor permissions independently of the
underlying vault's**. That's the mechanism behind Centrifuge's **deRWA** /
"restricted-to-freely-tradable" secondary-market distribution.

| Underlying | `asyncDeposit` | Deposit | Redeem |
|---|---|---|---|
| `SyncDepositVault` | `false` | immediate | async request → wait → redeem |
| `AsyncVault` | `true` | async request → wait → claim | async request → wait → redeem |

```
src/PassthroughVault.sol       vault + factory
src/interfaces/IPassthroughVault.sol, IUnderlyingVault.sol
src/libraries/QueueLib.sol     FIFO queue math
audits/2026-05-burraSec.pdf, 2026-05-Sherlock.pdf
```

## The caveat the README states plainly

Immutability is only the passthrough's own. It still sits inside the underlying
vault's trust model: **Centrifuge governance can cancel the passthrough's pending
requests**, and the cancelled funds land in a claimable-cancel balance the
passthrough has **no function to reach**. Such cancellations have to be
coordinated with the passthrough's operators out of band.

## Related

`protocol/src/vaults/`.
