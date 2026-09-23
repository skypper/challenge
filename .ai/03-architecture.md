# Architecture

Planning notes for the monitoring app. Decisions here are provisional until the Q&A answers in
`04-qa-questions.md` come back.

## 1. Shape: a cron job over pinned-block snapshots

Cron, not an event listener. Reasons:

- The events that matter are rare. Eleven settlement transactions in all of August 2026. A
  websocket subscription pays for idle time and adds a reconnect problem.
- Every invariant is evaluable from one pinned block: read the latest block, read state at that
  block, read logs since the last run, evaluate. Logs are durable, so nothing is missed between
  runs.
- Cron gives run history and monitor liveness for free ("last successful run").

Period: **1 hour**. Price pushes are daily, Chronicle changes daily, settlements take hours from
`ApproveRedeems` to `RevokeShares`. Hourly gives at most one hour of detection delay on the
slowest leg and ~720 runs a month.

## 2. Stack

- TypeScript on Node 20+. viem for RPC reads, `getLogs` with typed ABIs (decoded events without
  hand-rolled topic hashing), and multicall for batching state reads into one call per block.
- ABIs: copy from `../centrifuge/sdk/src/abi/*.abi.ts` (deployed v3.1 signatures) plus the
  Chronicle ABI fetched from Etherscan.
- Storage: JSON lines locally; DynamoDB or S3 on AWS. Same record shape.
- Tests: vitest with fixtures taken from real receipts (Aug 10, Aug 14, May 12 transactions).
- Config: RPC URLs and Etherscan key from env; addresses and identifiers in one `contracts.ts`.

## 3. Modules

```
src/
  contracts.ts       addresses, poolId, scId, assetId, ABIs          (from 01-forensic-pass)
  rpc.ts             viem client(s), pinned-block helpers, timeouts, retry
  snapshot.ts        collect(block) -> Snapshot   every field: {ok, value} | {ok:false, error}
  events.ts          fetch + decode logs in [fromBlock, toBlock] per contract, filtered on scId
  invariants/
    i1-freshness.ts        timer
    i2-agreement.ts        timer
    i3-settlement.ts       per RevokeShares / IssueShares event
    i4-conservation.ts     per event + timer
    i5-ledger.ts           timer, log only
    i6-admin.ts            per event
  verdict.ts         type Verdict = ok | alert | no_verdict, with evidence
  calibrate.ts       thresholds from a baseline block range (events only)
  replay.ts          run invariants over a historical range
  run.ts             one live tick: snapshot + events since cursor + evaluate + persist
  cli.ts             `run`, `replay --from --to`, `calibrate --from --to`, `status`
```

### Snapshot

```ts
type Read<T> = { ok: true; value: T; block: bigint } | { ok: false; error: string; block: bigint };

interface Snapshot {
  block: bigint; timestamp: number;
  spokePrice: Read<{ price: bigint; computedAt: number; maxAge: bigint }>;
  hubPrice: Read<{ price: bigint; computedAt: number }>;
  chronicle: Read<{ value: bigint; age: number }>;
  tokenSupply: Read<bigint>;
  tokenHook: Read<`0x${string}`>;
  escrowUsdc: Read<bigint>;
  escrowHolding: Read<{ total: bigint; reserved: bigint }>;
  bsAvailable: Read<bigint>;
  bsQueuedShares: Read<{ delta: bigint; isPositive: boolean; assetCounter: number; nonce: bigint }>;
  brmPending: Read<{ deposit: bigint; redeem: bigint }>;
  hubTotalIssuance: Read<bigint>;
}
```

Every read is pinned to `block`. A read that throws or times out (20 s) becomes `{ok:false}`;
the run continues.

### Invariant

```ts
interface Verdict {
  invariant: string;
  result: 'ok' | 'alert' | 'no_verdict';
  block: bigint; timestamp: number;
  inputs: Record<string, string>;          // raw values, stringified bigints
  threshold?: { value: number; unit: string; calibratedFrom: string };
  reason: string;                          // human sentence
  txHash?: `0x${string}`;                  // for per-event invariants
}
type Invariant = (s: Snapshot, events: DecodedEvents, t: Thresholds) => Verdict[];
```

Rule: if any input the invariant declares is `{ok:false}`, return `no_verdict` naming the field.
Never return `ok` on missing data.

### Cursor

`run` stores the last evaluated block. Next run fetches logs `(cursor, latest]`. If the gap
exceeds N blocks (a long outage), page the log fetch and still evaluate every event; do not skip.

## 4. The invariants (see 02-how-we-thought-about-it §4)

| id | trigger | inputs | verdict rule |
|---|---|---|---|
| I1 freshness | timer | spokePrice.computedAt, now | business-day age ≤ T_age |
| I2 agreement | timer | spokePrice, chronicle | \|Δ\| ≤ T_bps; chronicle.age ≤ T_chron |
| I3 settlement | each RevokeShares / IssueShares | event price, Chronicle at that block, Spoke computedAt at that block | \|Δ\| ≤ T_bps and age ≤ T_age |
| I4 conservation | each event + timer | RevokeShares, NoteWithdraw, escrow reads, vault pending | exact equalities |
| I5 ledger | timer | tokenSupply (all chains), hubTotalIssuance, bsQueued | log only |
| I6 admin | each File/Rely/Deny/VaultUpdate; timer on hook | token events, tokenHook | any change → alert |

Ship order for 8 h: I3 + I4 (first two equalities) + I1, with calibration and replay. I2, I5, I6 as
time allows, I5 log-only.

## 5. Calibration

`calibrate --from <block> --to <block>` reads only events (UpdateSharePrice, Poked) and emits:

```json
{ "window": {"from": ..., "to": ...},
  "pushLagBusinessDays": {"p50": 1, "p99": 3, "max": 3},
  "spokeVsChronicleBps": {"p50": 1.2, "p99": 3.6, "max": 3.9},
  "pokeIntervalMin": {"p50": 20, "p99": 45},
  "T_age": 4, "T_bps": 10, "T_chron": 120 }
```

Default window: Feb–Jul 2026, i.e. everything before the month under study. The design note
quotes the window, not the constants.

## 6. Replay

`replay --from --to` runs the same invariants at every settlement event block and at a fixed
timer cadence (e.g. every 6 h of blocks). State-based inputs are reconstructed from events where
possible (Spoke price, Chronicle value, escrow USDC via Transfer sums) and marked
`no_verdict: needs archive` where not (escrow `holding`, vault pending). With an archive RPC the
same code reads state directly.

## 7. Failure handling

- RPC: 20 s timeout, 2 retries with backoff, then `{ok:false}`. Two RPC URLs; if the primary
  fails the block-number read, use the secondary for the whole tick (never mix blocks).
- Snapshot older than 10 min at evaluation → all timer verdicts `no_verdict`.
- Chronicle unreachable → I3 degrades to its age clause, reason says so.
- Monitor liveness: `status` reports last successful tick; older than 2 × period is an alert on
  the monitor itself.
- Every verdict is self-contained (block, inputs, threshold, window) so a human can redo it.

## 8. Output

- `data/verdicts.jsonl` (append only), `data/latest.json` (last tick).
- CLI `status` prints a table: invariant, result, age, one-line reason.
- Alerting: for the exercise, stdout + non-zero exit on any `alert`. Later: SNS → Slack.
- Optional static dashboard reading `latest.json`; not in the 8 h scope unless time remains.

## 9. AWS-native later

- EventBridge Scheduler (hourly) → Lambda running `run`.
- Secrets in SSM Parameter Store; verdicts in DynamoDB (pk = invariant, sk = block); `latest`
  in S3 for a dashboard.
- Alerts: DynamoDB stream or the Lambda itself → SNS → Slack / PagerDuty.
- Lambda and local CLI share `snapshot`, `events`, `invariants`; only `run.ts` entry differs.
- Cost: hourly Lambda with ~20 RPC calls is effectively free; the RPC provider is the only bill.

## 10. Tenderly

Not the core, but two useful add-ons that match Soter's stack:

- **Tenderly Alerts** on `RevokeShares` / `IssueShares` at the BatchRequestManager, webhook →
  Lambda running only I3/I4 for that tx. Turns the settlement check event-driven without running
  a listener.
- **Tenderly Simulation** of a pending manager transaction (approve/revoke from the issuer key)
  to preview the price before it lands. This is the version of the monitor that prevents the
  incident instead of reporting it; mention as future work.

## 11. Open decisions (blocked on Q&A)

- Reference leg: Chronicle vs fund-admin file (Q1). Changes I2/I3 inputs.
- Chain: Ethereum vs Plume (Q2). Changes RPC config and replay ranges; code otherwise identical.
- Archive access (Q3). Changes what `replay` can prove for I4/I5.
