# How we thought about the problem

Brief: "We track this position and publish what it is worth; counterparties settle on that number.
Look at August 2026. Shares, the price we take from a third-party feed, and cash do not reconcile.
Build the monitoring that catches that class of problem."

Context from the job posting: Soter Labs runs risk and monitoring for Sky. Grove, Sky's credit
arm, is the $50M anchor holder of ACRDX. "We" is Sky's own book. The stack they name is
TypeScript, Tenderly, Foundry, Safe.

## 1. The trap: designing from the incident

The obvious approach is to find what happened in August and write a rule that fires on it. That
produces a rule tuned to one event, with thresholds that are numbers you picked after seeing the
answer. A public repo for this exact address does this: two checks, an 84-hour age threshold, a
0.15% divergence threshold. It fires on August. It cannot say why those numbers, and it is blind to
the two things that actually hurt counterparties (see §5).

We used the incident only as a **test set**, at the end.

## 2. Start from the promise

The brief's sentence contains four claims that have to hold every day:

1. the number we publish is **fresh**;
2. it **agrees with someone who does not share our signing key**;
3. it is the number **actually used when money moves**;
4. when money moves, **value is conserved**.

Plus one implicit claim: 5. **our ledger of shares and cash equals reality.**

Each claim becomes one invariant. None of them require knowing what happened in August.

## 3. Derive invariants from what the code does not enforce

Read the contracts and at every trusted value ask "who checks this?" Where the answer is nobody,
that is a monitor. Findings in the Centrifuge V3.1 code (deployed) and V3.3 (repo at `../centrifuge`):

| Trusted value | Who checks it on-chain | Consequence |
|---|---|---|
| Spoke price age | nobody: `maxAge = validUntil = uint64.max`; vault reads with `checkValidity=false`; `priceLastUpdated` = max(share, asset) so a fresh USDC price masks a stale share price | invariant 1 |
| price passed to `revokeShares` / `issueShares` | nobody: `_revokeShares` checks epoch sequencing only, stores the argument (`BatchRequestManager.sol:406`). Docs: "the published share price is the pool's reference price… the execution price… is set separately." V3.3 adds `StdHubPolicy.maxBrmPriceDeviation`; V3.1 has nothing | invariant 3 |
| hub `totalIssuance` / `Holdings` | nobody forces `submitQueuedShares`; `QueueManager` only flushes when `queuedAssetCounter == 0` (it is 1); a net-negative first flush would revert `NegativeIssuance` | invariant 5 (today: hub says 0) |
| escrow balance vs its own ledger | nobody: raw USDC balance, `holding.total`, `reserved`, and vault pending amounts are separate storage | invariant 4 |
| token `hook`, wards, vault link | nobody after the fact; a `file("hook", 0)` disables all restrictions | admin invariant |

## 4. The invariants

```
I1  freshness      now − Spoke.computedAt  ≤  T_age        (timer)
I2  agreement      |Spoke − Chronicle| / Chronicle  ≤  T_bps  (timer)
I3  settlement     for each RevokeShares/IssueShares at block X:
                     |price_used − Chronicle(X)| / Chronicle(X) ≤ T_bps
                     and  X.time − computedAt(price_used) ≤ T_age          (per event)
I4  conservation   payout == shares × price_used / price_asset  (exact)
                   NoteWithdraw.amount == payout               (exact)
                   USDC.balanceOf(escrow) == holding.total + Σ pendingDeposits
                   available == holding.total − reserved
                   per investor: requested == burned + cancelled + pending
I5  ledger         Σ supply(all chains) + escrow-held pending  ==  ShareClassManager.totalIssuance
                   queuedShares.delta / queuedAssets not growing without SubmitQueued*
I6  admin          token.hook, wards, vault(asset) unchanged; Chronicle tolled(address(0)) true
```

I3 is the one to build end to end. I4's first two lines make I3 credible (they prove the
arithmetic leg held, so the price leg is what failed). I1/I2 share I3's reads and are cheap.
I5 fails trivially today (hub = 0) and is a finding, not an alert. I6 is change detection.

## 5. Thresholds are outputs, not constants

Calibrate from a stated baseline window that excludes the period under study. From Feb–Jul 2026:

- push lag (push time − computedAt): T+1 on weekdays, T+3 over weekends → `T_age` = p99 + 1
  business day, expressed in business days;
- Spoke vs Chronicle gap: ≤ 4 bps in July → `T_bps` = k × p99;
- Chronicle poke interval: median 20 min → liveness threshold = multiple of that.

`calibrate()` runs against history and emits the thresholds with the window it used. The design
note quotes the window, not the number.

## 6. What the replay then found (validation, not input)

- **Aug 5 → Aug 16**: no price push for 10.9 days (I1). Hub and Spoke update in the same tx, so
  this was the issuer not publishing, not a bridge failure. Chronicle kept publishing.
- **Aug 14**: Spoke vs Chronicle +35.7 bps (I2).
- **Aug 10 and Aug 14**: `RevokeShares` at 1.020232 (the Aug 4 NAV) while Chronicle showed
  1.0210 / 1.0239 (I3). Payouts 120,194.39 and 24,002.02 USDC; I4 held to the cent.
- **May 12**: `RevokeShares` at 0.36145 for 588,066 shares (payout 212,556.92) with 378,868
  shares re-issued the same day: a position transfer through the redemption machinery at a
  non-NAV price. I3 fires at −64%. No freshness rule sees it. This is the strongest instance of
  the class in the token's history and the public repo cannot see it.
- I4 escrow identity holds today (253.06 = 154.06 + 99.00; 55.06 = 154.06 − 99.00). Verified on
  one state only; needs a second before alerting.

## 7. What we deliberately do not monitor

- Whether the NAV is *right*. Nobody publishes the fund's AUM on-chain; `Σ supply × price = NAV`
  is unverifiable. We can only check that two independent publishers agree and that settlement
  used one of them.
- USDC/USD. Priced 1.0 by construction in this pool (computedAt 2025-12-15).
- Other pools on the shared Spoke/BalanceSheet. Filter on scId or drown.
- Liability coverage (`pending × price` vs escrow cash). Cash is wired in from custody right
  before each fulfilment; it is always "uncovered" and that is by design. Log it; alert only if a
  fulfilment occurs without a preceding `NoteDeposit`.

## 8. When it cannot read

- A failed read gives `no_verdict`, never `ok`. "Could not check" is not "fine".
- Every invariant declares its inputs; if any input failed, the verdict is `no_verdict` with the
  failed field named.
- If Chronicle is unreachable, I3 degrades to its age clause only and says so.
- A snapshot older than N minutes at evaluation time is `no_verdict`.
- Every verdict carries block number, raw inputs, threshold and its calibration window, so a
  human can redo the arithmetic without the tool.
- The monitor's own liveness is a verdict: last successful run older than 2 × period → dead.

## 9. Open questions for the Q&A (submit ≥ 6 h before)

1. Is "the third-party feed" Chronicle `0x9a3b…7488`, or a fund-admin NAV file we receive?
2. Which chain do our counterparties settle on: Ethereum, or Plume where 98.8% of supply lives?
3. Is the May 12 epoch-2 revoke at 0.3614 known and intended?
4. Is the empty hub ledger (`totalIssuance = 0`) expected for this pool?
5. Tolerated price age: T+1 business day, or the T+3 seen around weekends?
6. Do we get archive RPC access (needed for historical escrow state; everything else is event-reconstructable)?
