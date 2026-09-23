# `centrifuge/tinlake` — Centrifuge V1

| | |
|---|---|
| **URL** | https://github.com/centrifuge/tinlake |
| **Tier** | V1 — historical, some pools still live |
| **Language** | Solidity (Foundry; originally dapptools) · **License** AGPL-3.0 |
| **Stars** | ~117 · **Last commit** 2022-12-29 |
| **Local size** | ~1.7 MB |

## What it is

The original Centrifuge: an Ethereum protocol for **onchain securitization**.
Borrowers tokenize a real-world asset as an NFT, lock it as collateral, and draw
against a pool; investors buy into one of two tranches.

Its two firsts, both genuine: **multiple tranches** and **revolving pools** in
DeFi. In mid-2021 a Tinlake pool became the first MakerDAO credit facility backed
by real-world assets.

## The two tokens

- **DROP** — senior, "yield" token. Stable, lower return, protected first.
- **TIN** — junior, "risk" token. Absorbs defaults first, takes the upside.

Straight junior/senior waterfall, which is why the codebase reads like structured
finance rather than like DeFi.

## Layout

```
src/borrower/
  shelf.sol       NFT custody + loan registry (lock/unlock collateral, borrow/repay)
  pile.sol        debt accounting with per-rate-group compounding interest
  feed/           NAV feed — discounted-cash-flow valuation of the loan book
  wrappers/       write-off wrappers
  deployer.sol, fabs/
src/lender/
  tranche.sol     one tranche's order book
  operator.sol    investor entry point
  assessor.sol    computes NAV, reserve, token prices, senior ratio
  coordinator.sol EPOCH LOGIC — closes epochs and executes the solver's result
  reserve.sol     liquidity
  token/          DROP / TIN
  adapters/       Maker (MIP21/MIP22) adapter
  admin/          pool admin
  definitions.sol
root.sol          ward-based auth root
fixed_point.sol
```

## The bit worth studying: epochs

Tinlake does not settle orders continuously. Investment and redemption orders
accumulate and are settled together at an **epoch close**, by solving a
constrained optimisation (maximise fulfilment subject to senior ratio, reserve
floor/ceiling, and available liquidity). `coordinator.sol` runs it;
`v2/clp-wasm` is the LP solver that was actually used.

V2 kept this model. V3 keeps the *word* but not the mechanism: its epochs are
four independent cursors per *(pool, share class, asset)*, advanced when a manager
approves rather than on a timer, with no solver — and the batching itself is an
opt-in request manager that sync-deposit vaults bypass. See
[`../ARCHITECTURE.md` §7.3](../ARCHITECTURE.md).

## Auth

The `ward` / `rely` / `deny` pattern throughout is inherited from **MakerDAO's
`dss`** — as are `tinlake-auth`, `tinlake-math` (DSR-style rate math) and
`tinlake-erc20` (copied from `dai.sol`). This lineage survives all the way into
`protocol/src/misc/Auth.sol`.

## Status

Legacy pools remain live and reachable via
[legacy.tinlake.centrifuge.io](https://legacy.tinlake.centrifuge.io/); no new
pools use these contracts. Audits: `security/audits/tinlake/` (Least Authority
v0.2.5 and v0.3.0, dapp.org lender review).

## Related

The satellite repos in `v1/` (see `v1-tinlake-satellites.md`),
`documentation/docs/getting-started/legacy/centrifuge-v1/`.
