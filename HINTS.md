# ACRDX (0x9477724b…) — study hints

Everything below was read live from Ethereum mainnet on 2026-09-22 (block ~26,032,000).
Re-read before quoting; numbers move.

## 1. What the contract is, and why it alone cannot tell you anything

`ShareToken` is a 200-line ERC-20 with three twists: balances are `uint128` + 16 bytes of
hook data per holder, every transfer/mint/burn calls a `hook` (currently `FullRestrictions`
0x4233…1608, a whitelist), and `authTransferFrom` lets any `ward` move anyone's tokens.
It has **no price, no NAV, no cash**. The three quantities in the brief live in different
contracts of the Centrifuge V3 stack, all on Ethereum:

| Quantity | Where it lives | Read |
|---|---|---|
| Shares (this chain) | ShareToken `totalSupply()` | 237,532.68 |
| Shares (hub view) | ShareClassManager 0xaFFC…9BEf `totalIssuance(pool, sc)` | **0** |
| Shares (other chains) | same token addr on Plume/Base, 0x2fab…3245 on Optimism | Plume 20.30M, OP 97.9k, Base 0 |
| Settlement price | Spoke 0xEC35…25aB `pricePoolPerShare(pool, sc, false)` + `markersPricePoolPerShare` | 1.023391284, computedAt 2026-09-18 12:00 |
| Vault view of price | AsyncVault 0x74A7…B712 `pricePerShare()`, `priceLastUpdated()`, `totalAssets()` | 1.023391 (6 dp), same computedAt |
| Third-party feed | Chronicle `ChronicleVAO_Centrifuge_ACRDX_Consumer_7` 0x9a3b…7488 `readWithAge()` (callable from address(0)) | 1.023391308, age 2026-09-21 21:29 |
| Cash (on-chain) | USDC `balanceOf(PoolEscrow 0x9fb6…218e)` vs PoolEscrow `holding(sc, USDC, 0)` vs BalanceSheet 0x12a1…f43e `availableBalanceOf` | 253.06 / (154.06 total, 99.00 reserved) / 55.06 |
| Cash (hub view) | Holdings 0x3f0c…918d `amount/value(pool, sc, usdcAssetId)` | **0, not initialised** |
| Liabilities | AsyncVault `pendingRedeemRequest(0, user)`, BatchRequestManager 0xc52b…fe77 `pendingRedeem(pool, sc, asset)` | 39,538.03 shares pending since Aug 14 |

Identifiers: poolId `281474976710664`, scId `0x00010000000000080000000000000001`,
USDC assetId `5192296858534827628530496329220097`.

## 2. What actually happened in August 2026

Price flow: an off-chain fund NAV is computed daily (computedAt is always 12:00 UTC of the
NAV date). Two independent parties push it on-chain: Centrifuge's manager pushes
`Spoke.UpdateSharePrice` (the number redemptions settle on), and Chronicle validators poke
their oracle (the number a third party publishes).

- **The Spoke feed stalled for 11 days.** Last push before the gap: Aug 5 15:47 (Aug 4 NAV,
  1.020232). Next push: Aug 16 13:32. Then a catch-up burst: nine backdated NAVs (Aug 5…Aug 21)
  pushed between Aug 16 and Aug 24, each with an old computedAt. Normal cadence is T+1.
- **Chronicle did not stall.** It pushed a new value every business day at ~13:30–14:30 UTC
  through the whole month. Divergence Spoke-vs-Chronicle grew from 0 to **+35.7 bps on Aug 14**
  and did not fall under 5 bps until Aug 21.
- **Two redemptions settled at the stale price.** Redeem epoch 3 (Aug 10: 117,810.79 shares →
  120,194.39 USDC) and epoch 4 (Aug 14: 23,526.03 shares → 24,002.02 USDC) were both revoked
  at `pricePoolPerShare = 1.020232466949343944`, the Aug 4 NAV. The Chronicle value at the
  Aug 14 fulfilment was 1.023879. Small in dollars here (~86 USDC), but it is exactly
  "counterparties settle on a number that no longer matches the feed".
- **Nothing on-chain could have stopped it.** `markersPricePoolPerShare` returns
  `maxAge = validUntil = type(uint64).max`; `checkValidity=true` never reverts. The USDC
  price is hard-coded 1.0 with computedAt 2025-12-15. The fulfilment price is an argument the
  manager passes to `revokeShares`; it is not checked against the current Spoke price.
- **The hub ledger is empty.** `totalIssuance = 0`, `Holdings` uninitialised, and
  `BalanceSheet.queuedShares` on Ethereum carries an unsubmitted lifetime delta of
  −252,647.79 shares. The protocol's own "shares × price = assets" bookkeeping is not in use
  for this pool, so any reconciliation has to be rebuilt from token supplies, escrow balances,
  and the two feeds.
- **Cash does reconcile, once you know the identities.** 253.06 USDC in escrow = 55.06
  available + 99.00 pending deposit (user 0x3541…d01e, `pendingDepositRequest`) + 99.00
  reserved. Escrow lifetime: 457,007.39 in, 456,754.33 out. Every fulfilment paid
  `shares × pricePoolPerShare` to the cent. The point is that the *price* was wrong, not the
  arithmetic.
- **A worse instance of the same class, in May.** Redeem epoch 2 (2026-05-12) revoked 588,066
  shares at `pricePoolPerShare = 0.36145` (payout 212,556.92 USDC) while NAV was ~1.016, with
  378,868 shares re-issued the same day to two new holders. It was a position transfer
  executed through the redemption machinery at a non-NAV price. A "fulfilment price within
  X bps of the feed" rule fires at −64% here; an "escrow in vs out" rule does not.

### Mechanics behind the above (from the Centrifuge repo at ../centrifuge; deployed code is v3.1, repo HEAD is v3.3-rc1, so use `sdk/src/abi/*.abi.ts` for deployed signatures)

- **The gap was the issuer, not the bridge.** Hub `ShareClassManager.UpdatePricePoolPerShare` and Spoke `UpdateSharePrice` fire in the *same transaction* for every update, including all of August. Nobody published between Aug 5 and Aug 16. Chronicle kept publishing, so Chronicle's source is not the Centrifuge push (it is an independent NAV source).
- **The published price is a reference, not the execution price.** Docs (`documentation/docs/developer/protocol/guides/publish-nav-and-oracles`): "This published share price is the pool's reference price across all networks. The execution price for individual deposit and redemption batches is set separately in the BatchRequestManager." `approveRedeems(…, pricePoolPerAsset)` and `revokeShares(…, pricePoolPerShare, …)` take the price as a plain argument from the pool manager; `_revokeShares` validates only epoch sequencing. v3.3 adds `StdHubPolicy.maxBrmPriceDeviation` for exactly this; v3.1 (deployed) has nothing.
- **Why the hub ledger is empty.** `totalIssuance` only moves when the spoke's queue is flushed by `submitQueuedShares`. `QueueManager.sync` submits shares only when `queuedAssetCounter == 0`; Ethereum's counter is 1 (USDC queue 456,908 in / 456,754 out never flushed). And a first submit with net-negative shares would revert `NegativeIssuance` on the hub. So it is structurally stuck, not just late.
- **Vault views mask staleness.** `AsyncVault.priceLastUpdated()` = max(share computedAt, asset computedAt); `convertToAssets` calls Spoke with `checkValidity=false`. A fresh USDC price would hide a stale share price (today both are stale-proof anyway because maxAge is unset).
- **Per-investor state** is one call: `AsyncRequestManager.investments(vault, investor)` → maxMint, maxWithdraw, depositPrice, redeemPrice, pending/claimable amounts.
- **Deployment address list**: `../centrifuge/sdk/src/config/deployments.ts` (Ethereum block 22–72) and `documentation/docs/developer/protocol/deployments/index.mdx`. Note two conflicting OracleValuation addresses and two conflicting centrifugeId tables (Plume = 4 or 6) in that repo; read `Holdings.valuation()` and `issuancePerNetwork()` on-chain rather than trusting either.

## 3. The class of problem

"Three sources that should agree, drifting apart silently, while settlement continues on
one of them." Concretely, for every fulfilment and every publish:

    shares_burned × price_used  ==  cash_paid            (arithmetic; always held)
    price_used                  ≈   third-party NAV       (failed in Aug, and in May)
    age(price_used)             ≤   cadence + tolerance   (failed Aug 5–16)
    Σ supply(all chains) + pending  ==  hub totalIssuance  (hub says 0 — unverifiable)

So the monitor's job is not to check the arithmetic; it is to check that the *inputs* to
the arithmetic are fresh, agree with an independent source, and that the ledger you settle
against is the one you think it is.

## 4. Everything that can be monitored on this contract and its neighbours

Ordered from "the contract itself" outward. Bold = worth doing end-to-end in 8 hours.

**On ShareToken itself (events + views)**
- `File("hook", addr)` — hook replaced (changed 3× in its life: Dec 15, Feb 3, Mar 9). A hook set to address(0) disables all restrictions.
- `Rely/Deny` — ward set changes; wards can mint, burn, `authTransferFrom` anyone's balance. Current wards worth enumerating: Root 0x7Ed4…368f, Spoke, BalanceSheet.
- `VaultUpdate(asset, vault)` — vault link changed (was unlinked Jan 30 → relinked Feb 4).
- `SetHookData(user, data)` — whitelist membership / freeze bits; 0x…ffffffff = member forever.
- `File("name"/"symbol")`.
- `Transfer` from/to address(0) — mints/burns; anything not originating from BalanceSheet/AsyncRequestManager is suspicious.
- `totalSupply()` vs sum of Transfer events (integrity), and `totalSupply ≤ uint128.max`.
- Holder concentration: 3 holders on Ethereum today (one investor 197,993.65, escrow 39,538.03, one test address 1.0).

**Price (the August failure)**
- **Age of `Spoke.pricePoolPerShare`**: now − computedAt, and push time − computedAt (lag). Alert when > 3 business days; the repo's markers give you nothing (maxAge is unset) so you must compute it yourself.
- **Spoke vs Chronicle divergence** in bps, and Chronicle's own age from `readWithAge()`.
- Backdated pushes: computedAt not monotonically ≥ previous, or a push whose computedAt is > N days old.
- Chronicle liveness: no `Poked` for > 2 h (median gap is 20 min); `tolled(address(0))` flipping to false (reads would start reverting).
- Vault `pricePerShare()` (6 dp) vs Spoke (18 dp) rounding, and vault `priceLastUpdated()` == Spoke computedAt.
- Same price/computedAt on every chain's Spoke (today they are identical; a lagging chain means a lagging settlement venue).

**Settlement (the thing that hurts counterparties)**
- **`RevokeShares.pricePoolPerShare` and `IssueShares.pricePoolPerShare` on BatchRequestManager vs Chronicle/Spoke at that block** — this single check catches both Aug 10/14 and May 12.
- `payoutAssetAmount == approvedShareAmount × price` (arithmetic), and `payoutAssetAmount == BalanceSheet.NoteWithdraw.amount == USDC Transfer out of escrow`.
- Pending redeem age: `pendingRedeemRequest` outstanding > N days (39,538 shares have waited 5 weeks).
- `ApproveRedeems` partial fills: approved / pending ratio.

**Cash**
- `USDC.balanceOf(escrow)` == `escrow.holding.total` + Σ `pendingDepositRequest`; and `BalanceSheet.availableBalanceOf` == total − reserved. Alert on any unexplained residual.
- OnOfframpManager `NoteDeposit/Deposit/Withdraw` — cash moving between chain and off-chain accounts; cash that leaves without a matching hub `Holdings` update is invisible to the protocol (as it is today).
- `BalanceSheet.queuedAssets/queuedShares` growing without `SubmitQueued*` for this scId.

**Cross-chain / hub**
- Σ `totalSupply` over Ethereum, Plume, Optimism, Base (+ Monad) + escrow-held pending, vs `ShareClassManager.totalIssuance` (currently 0 → the check is "the hub ledger is not maintained", which is itself the finding).
- `issuancePerNetwork(pool, sc, centrifugeId)`, `Holdings.isInitialized`.
- Gateway/adapter message failures (Wormhole/Axelar) would show as hub-updated-but-spoke-silent on remote chains. On Ethereum hub and spoke update in one tx, so compare Plume/Base/OP spoke computedAt to the hub's.

**Admin / governance**
- Root `Rely/Deny`, `ScheduleRely/CancelRely`, pause; HubRegistry `manager(pool, who)` changes; BalanceSheet `UpdateManager`; AsyncRequestManager `Rely` (eight in August alone, all for *other* pools — filter by poolId or you drown).

## 5. What to deliberately not monitor (and say so in the note)

- USDC/USD depeg — priced 1.0 by construction in this pool; it is a different system's problem.
- Off-chain NAV correctness (whether Apollo's number is right). You can only check agreement between two publishers of it.
- Every pool on the shared Spoke/BalanceSheet — filter on poolId/scId or the alert stream is noise.
- Gas, mempool, MEV — no user-facing swap path exists (whitelisted, async).
- ERC-20 approvals — irrelevant to settlement.

## 6. "When it cannot read"

Failure modes you will hit, each observed while doing this:
- RPC down / archive not available for the block you want (Etherscan v2 needs a key; Sourcify had no match; publicnode is fine for `latest`).
- `eth_call` reverts: `pricePoolPerShare(…, true)` if validity were ever enforced; Chronicle `read()` if address(0) loses toll; `latestRoundData()` does not exist on this oracle.
- Etherscan log API caps at 1000 results per page and silently returns a string on bad topics.
- Two sources disagree on *time* (Chronicle `age` is validator time; Spoke `computedAt` is NAV date noon UTC).

The rule the other public solution for this exact address uses is a good one: a read that
fails yields `no_verdict`, never `ok`. Add: a stale read (block older than N minutes) is also
`no_verdict`; a check whose *reference* input (Chronicle) is missing degrades to a
single-source age check and says so; and every alert carries the block number and both raw
values so a human can re-derive it.

## 7. Questions worth submitting to the Q&A

1. Is "the price we take from a third-party feed" Chronicle 0x9a3b…7488, or a fund-admin NAV file? (Determines the reference leg.)
2. Which chain do your counterparties settle on — Ethereum, or Plume where 98.8% of supply lives?
3. Is the May 12 epoch-2 revoke at 0.3614 known/intended? It is the strongest instance of the class in the history.
4. Is the hub ledger (totalIssuance = 0) expected to be empty for this pool, or is that itself the bug?
5. What is the tolerated price age: T+1 business day, or the T+3 seen around weekends?

## 8. Useful commands

```
source .env; export ETH_RPC_URL=https://ethereum-rpc.publicnode.com
SPOKE=0xEC3582fcDc34078a4B7a8c75a5a3AE46f48525aB; POOL=281474976710664; SC=0x00010000000000080000000000000001
cast call $SPOKE 'pricePoolPerShare(uint64,bytes16,bool)(uint128)' $POOL $SC false
cast call $SPOKE 'markersPricePoolPerShare(uint64,bytes16)(uint64,uint64,uint64)' $POOL $SC
cast call 0x9a3bF392f86acd1b1EC07d026B326302eAED7488 'readWithAge()(uint256,uint256)'
cast call 0xc52bd1bdfa0135147d3f01a0b6d6cd0a831dfe77 'epochRedeemAmounts(uint64,bytes16,uint128,uint32)(uint128,uint128,uint128,uint128,uint128,uint64)' $POOL $SC 5192296858534827628530496329220097 4
```
Event topics: `UpdateSharePrice` 0x50ae9491…, Chronicle `Poked` 0x9f8b8154…, `Transfer` 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef.
August 2026 block range: 25,656,292 → 25,878,704.
