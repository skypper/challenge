# What "we track this position and publish what it is worth" means

Evidence gathered 2026-09-23 from Soter Labs' public GitHub (`github.com/soterlabs`), the
Plume RPC, and the Ethereum data already in `01-forensic-pass-data-access.md`.

## 1. Who "we" is, and what gets published

Soter Labs runs settlement and monitoring for Sky. Sky lends USDS to "prime agents" (Grove,
Obex, Osero, Spark…). Each month Soter produces a **Monthly Settlement Cycle (MSC)** report per
prime: the value of every position the prime holds, the revenue it earned, and what the prime
and Sky owe each other. Grove and Sky then settle cash on those numbers. That is "counterparties
settle on that number".

Where it is published (repo `soterlabs/settlement-reports`, path `reports/grove/2026-08/`):

| File | Content |
|---|---|
| `summary.md` | headline + per-venue table (value start/end of month, inflow, revenue) |
| `grove_settlement_august_2026.xlsx` | same data, six sheets, the one humans sign off |
| `provenance.json` (frozen copy in `soterlabs/tally/test/fixtures/msc/settlements/grove/2026-08/`) | the pipeline's full-precision output the summary is derived from |

Cadence: **monthly**, authoritative. A **Daily Settlement Cycle (DSC)** pilot exists in
`soterlabs/tally` (Solidity, unaudited, not deployed): the same books recomputed on-chain every
UTC day, with a replay of August 2026 checked in under `reports/grove-2026-08*`.

The dashboard `settle.soterlabs.com` (`soterlabs/msc-dashboard`) renders the settled tier from
committed JSON, refreshed monthly through a reviewed PR.

## 2. How a position is valued

Tally's adapter interface (`src/pips/Pip.sol`):

```
peek(who) -> (pie, chi, own)
  pie  shares held, incl. in-flight          [wad]
  chi  price per share                       [ray]
  own  claims owned outside the shares       [wad]
value    = pie * chi + own
index PnL = old pie * (new chi - old chi)
flow      = new value - old value - index PnL
```

Per venue: `revenue = value_eom − value_som − period_inflow`. Shares × price is "value";
"period inflow" is the cash leg. If the cash that actually moved was priced differently from
`chi`, the residual lands in revenue. That is the mechanism by which "shares, price, cash do
not reconcile" shows up.

Price sources in Tally:
- `ChroniclePip`: `chi = Chronicle.read()` — used for STAC, JAAA/JTRSY fallback. The Chronicle
  oracle is the third-party feed. `ARCHITECTURE.md`: "Chronicle read permission is not a
  freshness policy."
- `Erc7540Pip`: `chi = vault.convertToAssets(1 share)` — the Centrifuge Spoke price. Pending
  redeems count in `pie` (still floating), claimable redeems in `own` (fixed at fulfilment price).
- `RelayPip`: for positions on other chains, an operator pushes `(pie, chi, own)`; a mark older
  than `hop = 1 day` makes `peek` revert. "A settlement that cannot read its inputs must stop,
  not guess."

## 3. ACRDX in Grove's August 2026 settlement

ACRDX is **venue E22, chain `plume`**, coverage "Remote position" (relayed, not read locally).
Grove's Ethereum ALM (`0x491EDFB0…3a44e`) is whitelisted on the Ethereum token but holds none;
the position is on Plume (holder `0x1db91ad5…f812`).

Three versions of the same venue in Soter's own files:

| Source | value_som | value_eom | period_inflow | revenue |
|---|---:|---:|---:|---:|
| `provenance.json` | 32,853,651.73 | 20,703,791.97 | −12,283,229.22 | **133,369.45** |
| `summary.md` | 32,853,651.73 | 20,703,791.97 | −12,263,707.47 | **113,847.70** |
| `.xlsx` Venues sheet | 32,853,651.73 | 20,703,791.97 | −12,149,859.77 | 113,847.70 |

Shares and value agree everywhere. **Cash does not.** The Tally fixture README names it:
"Grove E12 and E22 discrepancies … are exposed in the generated comparison."

## 4. Where the cash numbers come from (on-chain)

Plume tx `0x9436d124e15bea9def739ab01daf192f8c70b87d16787bbdddba2868ced5008e`,
block 86,442,086, **2026-08-10 17:30:50 UTC**: `BalanceSheet.Revoke` of
**12,020,502.0395381 shares at pricePoolPerShare 1.020232466949344**, called directly by
`0x8ef19b8c…0c3c` (not via BatchRequestManager epochs). Same stale price, same day, as the
Ethereum epoch-3 redemption.

```
12,020,502.04 × 1.020232  (Centrifuge execution price, Aug 4 NAV)  = 12,263,707.5   = summary.md inflow
12,020,502.04 × 1.021857  (Chronicle, Aug 10 NAV)                  = 12,283,229.2   = provenance inflow
12,020,502.04 × 1.010762  (?)                                      = 12,149,859.8   = xlsx inflow
difference summary vs provenance                                   =     19,521.7   ≈ 133,369.45 − 113,847.70
```

So the August reconciliation failure, in Sky's own books, is: **the position was marked at the
third-party price, but the redemption cash came in at Centrifuge's stale execution price, and
the 16 bps gap on 12M shares (≈19.5k USDS) surfaced as a revenue disagreement between two
versions of the same report.** The xlsx carries a third cash figure at a price we could not
source; ask.

## 5. Consequences for the design

- The reference leg is Chronicle (Q1 answered). The settlement leg is the Centrifuge
  `Revoke`/`RevokeShares` price. The cash leg is the USDC that actually moved.
- The chain that matters is **Plume** for the position, **Ethereum** for the hub and for
  Chronicle's canonical feed (Q2 answered; Plume has its own Chronicle ACRDX oracle, address
  to confirm).
- Soter's own convention for stale data is RelayPip's `hop = 1 day` and "revert, don't guess"
  (Q6 partly answered): the monitor should adopt 1 business day as the default freshness bound
  and treat an unreadable input as a stop, not an `ok`.
- The monthly report is the artifact to protect. A check that runs daily and compares
  `shares × Chronicle` against `cash at execution price` for every revoke would have flagged
  E22 on Aug 10, three weeks before the report was cut.
- Plume redemptions bypass the epoch machinery (direct `BalanceSheet.revoke` by a manager), so
  the settlement invariant must listen to **BalanceSheet `Revoke`/`Issue` on every chain**, not
  only BatchRequestManager on Ethereum.

## 6. Addresses added by this pass

| What | Where | Address |
|---|---|---|
| Grove Ethereum ALM | Ethereum | `0x491EDFB0B8b608044e227225C715981a30F3A44E` |
| ACRDX holder that redeemed | Plume | `0x1db91ad50446a671e2231f77e00948e68876f812` |
| Manager that called `revoke` | Plume | `0x8ef19b8cee9dfdce42ffbc405ba828dc6e920c3c` |
| BalanceSheet | Plume (same as Ethereum) | `0x12a110ce5f0fc871cc72bc7ecaf35cf39dd0f43e` |
| STAC Chronicle oracle (for comparison) | Ethereum | `0x802CaCc19B9b3eb474C7DEf6f28c64AB67fb0753` |
| Chronicle authed owner (kiss) | Ethereum | `0x62a69d7832040Cd629Ee2f712b4C8639C0F905D7` |
| Plume August block range (approx.) | Plume | 84,571,497 → 90,639,614 (~2.27 blocks/s) |

Repos: `soterlabs/settlement-reports`, `soterlabs/tally`, `soterlabs/msc-dashboard`,
`soterlabs/monitoring-bot` (their Telegram cron-bot pattern: Railway cron, TypeScript, tsx).
