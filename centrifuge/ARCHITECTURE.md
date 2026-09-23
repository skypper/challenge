# Centrifuge V3 — Design, Architecture & Data Inventory

*A learning document. Written from the source at `protocol/` (v3.3.0-rc1, 2026-09-03),
`sdk/` (2.3.1) and `api-v3/` (4.4.1). Read top to bottom; every section names the
files it came from so you can go verify it.*

---

## Table of contents

1. [What the protocol is for](#1-what-the-protocol-is-for)
2. [The five design commitments](#2-the-five-design-commitments)
3. [Identity: the type system](#3-identity-the-type-system)
4. [The Hub — a pool's control plane](#4-the-hub--a-pools-control-plane)
5. [The Spoke — a pool's local presence](#5-the-spoke--a-pools-local-presence)
6. [Messaging — how the two halves talk](#6-messaging--how-the-two-halves-talk)
7. [Vaults — how investors get in and out](#7-vaults--how-investors-get-in-and-out)
8. [The share token and compliance](#8-the-share-token-and-compliance)
9. [Valuation, NAV and price](#9-valuation-nav-and-price)
10. [Authority: wards, guardians, policies](#10-authority-wards-guardians-policies)
11. [Extension points](#11-extension-points)
12. [Data inventory — onchain](#12-data-inventory--onchain)
13. [Data inventory — the message wire format](#13-data-inventory--the-message-wire-format)
14. [Data inventory — offchain (api-v3)](#14-data-inventory--offchain-api-v3)
15. [Deployment topology](#15-deployment-topology)
16. [Five walkthroughs](#16-five-walkthroughs)
17. [Design decisions worth arguing with](#17-design-decisions-worth-arguing-with)
18. [How to keep learning](#18-how-to-keep-learning)

---

## 1. What the protocol is for

An **issuer** (a fund manager, a credit desk, a treasury) wants to put a financial
product onchain: a tokenized treasury fund, a private-credit portfolio, a
market-neutral strategy. They want investors on several chains, they want NAV and
accounting to be correct and auditable, and — because the underlying is often
regulated — they need transfer restrictions.

Centrifuge V3 gives them:

- a **pool**, which is one balance sheet;
- one or more **share classes** inside it, each an ERC-20 **share token**;
- **vaults** (ERC-4626 / ERC-7540) through which investors subscribe and redeem;
- **holdings** and a **double-entry ledger** that value what the pool owns;
- and the machinery to run all of that across **many chains at once** while the
  books stay consolidated in one place.

The protocol is deliberately *non-opinionated*. It does not know what an asset
is, how to price it, who may hold shares, or when orders settle. Those are all
extension points. What it guarantees is that the accounting balances, the
messages are authentic, and the core can never be upgraded out from under you.

---

## 2. The five design commitments

Everything else follows from these. They are stated in `src/core/README.md`; the
consequences are visible all over the code.

### 2.1 The core is immutable

`src/core/` — hub, spoke, messaging, types — is deployed once and never upgraded.
Not "upgradeable behind a timelock": there is no proxy. This is why the core
carries no product logic: a bug in product logic would be unfixable.

**Consequence you can see in the code:** core holds *interface references that
default to zero*, and a zero address means the feature is skipped. `Holdings` has
`snapshotHook`, `HubRegistry` has `bridgingHook` and `hubRequestManager`,
`ShareToken` has a `hook`. Every one is opt-in per pool. Core never depends on an
extension; extensions depend on core.

### 2.2 One pool, one set of books, many chains

A pool has a **hub chain** — chosen by the operator, any of the 11 — and any
number of **spoke chains**. The hub holds authority and accounting and *never
custodies user assets*. Each spoke custodies assets and issues shares locally.

The two sides are built as deliberate mirrors, which is the single most useful
fact for navigating the codebase:

| Hub | Spoke |
|---|---|
| `Hub` | `Spoke` |
| `HubHandler` (inbound messages) | `SpokeHandler` |
| `HubRegistry` | `SpokeRegistry` |
| `Holdings` | `SnapshotQueue` |

### 2.3 Transport security is a quorum, not a bridge

No single bridge is trusted. `MultiAdapter` holds a per-(destination, pool) set
of adapters and a threshold; a payload executes only once `threshold` distinct
adapters have voted for **byte-identical** bytes. Ethereum↔everything currently
runs Axelar + LayerZero with threshold 2 (`env/mainnet/connections.json`).

### 2.4 Accounting cannot go unbalanced

`Accounting` is a real double-entry engine with a lock/unlock discipline:
`unlock(poolId)` → add debits and credits → `lock()`, and `lock()` **reverts
unless `debited == credited`**. There is no code path that writes an unbalanced
journal, because the check is in the close, not in each entry.

### 2.5 Cross-chain execution is paid onchain, at dispatch

`Gateway` settles the adapter cost from `msg.value` as part of sending, refunds
the remainder, and — in "unpaid mode" — records an underfunded batch that anyone
can later settle with `repay()` instead of reverting. Fees are protocol state,
not an offchain relayer's problem.

---

## 3. Identity: the type system

`src/core/types/` — five user-defined value types. Read these first; they encode
the domain model more compactly than any diagram.

```solidity
type PoolId       is uint64;    // [uint16 centrifugeId | uint48 localPoolId]
type ShareClassId is bytes16;   // [uint64 poolId | uint32 index]
type AssetId      is uint128;   // [uint16 centrifugeId | uint64 counter]  (or a bare ISO-4217 code)
type AccountId    is uint256;   // [centrifugeId|index]  or  [assetId|index]
type RequestId    is uint256;   // opaque; ERC-7540/ERC-8161 request id
type D18          is uint128;   // fixed point, 18 decimals
```

Four things worth noticing:

1. **`centrifugeId` is not `chainId`.** It is a compact protocol-internal chain
   id (Ethereum = 1, Base = 2, Arbitrum = 3, …). It is embedded in `PoolId` and
   `AssetId`, so *the identifier itself tells you which chain the pool is hubbed
   on and which chain an asset lives on*. `Hub.createPool` enforces
   `poolId.centrifugeId() == localCentrifugeId`, i.e. you can only create a pool
   whose id says it is hubbed here.
2. **`ShareClassId` is derived, not assigned:** `newShareClassId(poolId, index)`.
   A share class id cannot belong to the wrong pool.
3. **`AssetId` covers both tokens and currencies.** `newAssetId(uint32 isoCode)`
   makes a pool's denomination currency (say USD) the same type as a real ERC-20,
   so `Holdings` needs no special case for "the pool currency".
4. **`D18` prices are always oriented,** and the variable names say which way:
   `pricePoolPerShare`, `pricePoolPerAsset`, `priceAssetPerShare`. `PricingLib`
   converts between asset, share and pool units carrying decimals explicitly. If
   you are ever confused by a conversion in this codebase, the answer is in
   `src/core/libraries/PricingLib.sol`.

`AccountId` composition is subtle and matters for NAV: `withCentrifugeId(id,
index)` and `withAssetId(assetId, index)` mean the accounting taxonomy is
*derived*, not stored — `NAVManager` gives every network its own equity /
liability / gain / loss accounts and every asset its own asset / expense accounts
purely by construction. The code notes the trap: because the ids come from enum
ordinals, **the taxonomy is append-only** — reordering the enum silently repoints
existing pools' accounts.

---

## 4. The Hub — a pool's control plane

`src/core/hub/` · one deployment per chain, but a given pool only uses the one on
its hub chain.

### 4.1 `HubRegistry` — what exists, and who may touch it

Canonical registry: pools, their currency and decimals, registered assets, pool
metadata, managers, the per-(pool, destination-chain) `IHubRequestManager`, the
optional `IBridgingHook`, and — the interesting part — **the policy and its
authorization ledger**.

```solidity
mapping(AssetId => AssetInfo) public asset;
mapping(PoolId => AssetId) public currency;
mapping(PoolId => mapping(address => bool)) public manager;
mapping(PoolId => PolicyInfo) internal _policy;          // {policy, nonce}, one slot
mapping(bytes32 authId => uint48 validAfter) public authorizedAfter;
mapping(PoolId => IBridgingHook) public bridgingHook;
mapping(PoolId => mapping(uint16 => IHubRequestManager)) public hubRequestManager;
```

The ledger is three operations — `initiateAuthorization`, `cancelAuthorization`,
`consumeAuthorization` — and one id:

```solidity
authId = keccak256(poolId, policyAddress, policyInstallNonce, calldata)
```

Three properties fall out of that id, and each is deliberate:

- Authorization is over **exact calldata**. Not a selector, not a role: the bytes.
- It is namespaced by the **policy address and its install nonce**, so *installing
  a new policy makes every outstanding authorization unreachable* without having
  to enumerate and delete them.
- `consumeAuthorization` requires `block.timestamp >= validAfter` **and**
  `<= validAfter + expiry`. A matured authorization that is never used **expires**
  — it fails closed rather than sitting armed forever, so it can't be fired months
  later once conditions have drifted and nobody is watching.

### 4.2 `Accounting` — double entry, transiently journaled

`src/core/hub/Accounting.sol`, 160 lines, and worth reading in full.

```solidity
struct Account { uint128 totalDebit; uint128 totalCredit; bool isDebitNormal;
                 uint64 lastUpdated; bytes metadata; }
mapping(PoolId => mapping(AccountId => Account)) public accounts;
uint128 public transient debited;
uint128 public transient credited;
PoolId  internal transient _currentPoolId;
```

Accounts store **cumulative** debit and credit totals, never a net. `accountValue`
derives the net at read time and returns `(isPositive, magnitude)` — so a
debit-normal account that goes credit-heavy is representable rather than a revert.

`unlock` / `lock` bracket a journal. Journal ids live in transient storage keyed
by pool (`TransientJournal`), so several pools' entries can interleave inside one
transaction and each pool's entries still share one journal id. That is a small
detail with a real consequence: **a multicall touching three pools produces three
coherent journals, not one jumbled one.**

Everything that posts goes through `Hub._journal(...)`, which does
`unlock → addDebit → addCredit → lock`. Two debits, one credit. Always balanced.

### 4.3 `Holdings` — the ledger of what the pool owns

```solidity
struct Holding {
    uint128 increasedAmount;   // cumulative, like a mint total
    uint128 decreasedAmount;   // cumulative, like a burn total
    uint128 assetAmountValue;  // carrying value in pool currency
    IValuation valuation;      // also serves as the existence flag
}
```

**Why two counters instead of one balance.** Amounts arrive from spokes
asynchronously and are rounded. A decrease can legitimately arrive before the
increase that justifies it, or rounding can push a decrease past the current
balance. With a single clamped balance that excess would be silently lost and the
hub would permanently disagree with the spoke. With cumulative counters the
over-decrease is *carried* on `decreasedAmount` and nets against the next
increase. `_amount()` = `increased - decreased`, floored at zero.

The pair of value functions is where the real thinking is:

- **`increase`** values only the *realized* portion (any preceding over-decrease
  is netted off first) at a **live valuation quote**.
- **`decrease`** removes carrying value **pro-rata**, deliberately *not* a live
  quote. The comment in the source explains why: pro-rata preserves the invariant
  `amount == 0 ⟹ value == 0`. A live quote would break it — if the price moved
  since the last `update()`, a full drain would leave residual value stranded in
  the books.
- **`update`** re-marks the whole holding to the current valuation and returns the
  signed difference, which `Hub` books as a gain or loss.

That is the amount/value split in one sentence: **amount changes are principal,
value changes are P&L**, and they hit different account slots.

`Holdings` also maintains two **deficit counters** — per (pool, share class,
network) and a per-(pool, network) rollup — tracking how many holdings currently
have decreases outrunning increases. A NAV hook gates on the rollup, because the
NAV it publishes is pooled across share classes and would be wrong while any
component is in deficit.

### 4.4 The four account slots

`AccountKind` (in `IHub.sol`) has exactly four members, and core has **no opinion
on their accounting meaning**:

| Slot | Booked on |
|---|---|
| `AmountDebit` | the holding's own account (asset or expense side) |
| `AmountCredit` | amount-change counterpart (equity or liability side) |
| `ValueIncrease` | revaluation gain counterpart |
| `ValueDecrease` | revaluation loss counterpart |

The posting rules in `Hub`:

```
amount up      : debit  AmountDebit    credit AmountCredit
amount down    : debit  AmountCredit   credit AmountDebit
value up       : debit  AmountDebit    credit ValueIncrease
value down     : debit  ValueDecrease  credit AmountDebit
```

**Four slots is a design choice, not a limitation.** A liability is not a fifth
slot — it is a holding whose counterpart slots point at liability-normal
accounts. The pool assigns the four `AccountId`s at `initializeHolding` and can
repoint any of them later with `setHoldingAccountId`. That is how one mechanism
covers assets, liabilities, expenses and fees.

> There is a migration note in the source: v3.1.0 used a different enum
> (`AccountType {Asset, Equity, Loss, Gain, Expense, Liability}`) whose ordinals
> differ, so the migration spell must remap Loss→ValueDecrease and
> Gain→ValueIncrease. A good illustration of the append-only warning above.

### 4.5 `ShareClassManager` — issuance as monotonic counters

```solidity
struct IssuanceCounters { uint128 issuances; uint128 revocations; }
mapping(PoolId => mapping(ShareClassId => IssuanceCounters)) issuanceAcrossNetworks;
mapping(PoolId => mapping(ShareClassId => mapping(uint16 => IssuanceCounters))) issuancePerNetwork;
```

Same trick as `Holdings`, for the same reason, and this time the source spells
out the failure it avoids: if a revocation arriving before its issuance
*reverted*, the reporting chain would be permanently unable to report anything
further. So the counters always accept.

The netted views (`issuance`, `totalIssuance`) **revert** while revocations exceed
issuances — refusing to answer, because the figure would be missing shares the
hub has not yet been told about. The raw counters
(`issuanceAcrossNetworks`, `issuancePerNetwork`) are always readable.
`negativeNetworkCount` tracks how many networks are currently in that state.

This is a pattern worth internalizing: **accept every write, refuse the derived
read.** It appears three times in this codebase (holdings deficit, issuance
negativity, snapshot consistency) and it is what lets an eventually-consistent
multi-chain system stay sound without global locks.

---

## 5. The Spoke — a pool's local presence

`src/core/spoke/` · deployed on every chain a pool operates on.

### 5.1 What lives where

- **`SpokeRegistry`** — pools, share classes (each pairing a share token with the
  `IRegistrar` that operates it), local-address↔`AssetId` mapping, prices, the
  per-pool `requestManager`, the `manager` and `bridger` roles, the installed
  policy, a consume-only authorization ledger, and `VaultDetails` for every vault.
- **`Spoke`** — the single user- and manager-facing contract. `BatchedMulticall`,
  so a whole cascade folds into one cross-chain payload.
- **`SpokeHandler`** — inbound messages from the hub.
- **`PoolEscrow`** — custody, per pool, per share class.
- **`SnapshotQueue`** — local deltas awaiting a flush to the hub.

### 5.2 `PoolEscrow` — segregated custody with named reservations

```solidity
struct Holding { uint128 total; uint128 reserved; }
mapping(ShareClassId => mapping(address asset => mapping(uint256 tokenId => Holding))) holding;
mapping(ShareClassId => mapping(address reserver => mapping(bytes32 reason =>
        mapping(address asset => mapping(uint256 tokenId => uint128))))) reservedBy;
availableBalance = total - reserved
```

Two things to notice.

**Custody is per pool and per share class.** V2 had one global `Escrow`. Here each
pool gets its own escrow contract, deployed deterministically by
`PoolEscrowFactory`, and balances are tracked per share class inside it. A bug or
a compromise in one pool cannot reach another pool's assets.

**Reservations are attributed.** `reservedBy[scId][reserver][reason][asset][tokenId]`
— so a reservation is owned by *who* made it and *why*, and `unreserve` checks
that specific slot. One holder of reserved funds cannot release another's. The
reasons are constants like `REASON_DEPOSIT` and `REASON_REDEEM` in
`AsyncRequestManager`.

### 5.3 `SnapshotQueue` — netting before you pay for a message

```solidity
struct ShareQueueAmount { uint128 delta; bool isPositive; uint32 queuedAssetCounter; uint64 nonce; }
struct AssetQueueAmount { uint128 deposits; uint128 withdrawals; }
```

Share deltas are **netted** (issue adds, revoke subtracts, stored as
magnitude + sign). Asset flows are **accumulated gross** per asset — deposits and
withdrawals kept separately, netted only at flush. Flushing returns
`UpdateData { netAmount, isIncrease, isSnapshot, nonce }` and bumps the nonce.

The clever field is **`isSnapshot`**, and it is the heart of cross-chain
consistency:

```solidity
// flushing assets:
isSnapshot = shareQueue.delta == 0 && shareQueue.queuedAssetCounter == assetCounter;
// flushing shares:
isSnapshot = shareQueue.queuedAssetCounter == 0;
```

`isSnapshot` is true exactly when **this flush leaves nothing else queued for this
share class on this chain** — i.e. the hub is about to have a complete, consistent
picture of that chain. `Holdings.setSnapshot` records it (guarded by the nonce, so
updates cannot be reordered) and fires `ISnapshotHook.onSync`. That is the signal
`NAVManager` waits for before computing a NAV: **derived figures that depend on
the asset/share ratio are only computed at moments when the ratio is known to be
consistent.**

### 5.4 The balance-sheet operations

All on `Spoke`, all gated by `enforced(poolId)` (manager role + pool policy):

| Operation | Escrow | Queue | Token |
|---|---|---|---|
| `deposit` | `+total` | assets +, `isIncrease` | pulls ERC-20/6909 from caller |
| `noteDeposit` | `+total` | assets +, `isIncrease` | — (assets already arrived) |
| `withdraw` | `-total` | assets −, `isIncrease=false` | `authTransferTo(receiver)` |
| `reserve` | `+reserved` | assets − | — |
| `unreserve` | `-reserved` | assets + | — |
| `issue` | — | shares +, issuance | `registrar.mint(to)` |
| `revoke` | — | shares −, revocation | pull, approve, `registrar.burn` |

Notice `reserve` queues an asset *decrease* and `unreserve` an *increase*. That is
what makes the deposit flow work: reserving pending funds removes them from the
hub-accounted holding without moving them, so a pending subscription is not
counted in NAV and does not consume withdrawal headroom.

### 5.5 Cross-chain share transfer: burn and mint

`crosschainTransferShares` requires all of: caller is the owner or a ward, the
owner holds the pool's **`bridger`** role, and the share class registrar's
**`canBridge`** check passes. Then the shares are pulled in, burned locally, and
an `InitiateTransferShares` message goes out. On arrival, `HubHandler` passes it
through the pool's optional `IBridgingHook` — which **may rewrite receiver,
amount, gas limit and refund address** — before reissuing on the destination.

`BridgeCircuitBreaker` is the reference hook: per-(pool, share class) pause plus a
fixed-window rate limit per origin network, with a pre-authorization escape hatch
(a hub manager can name an exact transfer tuple so a single transfer larger than
`rateMax` can pass).

`src/bridge/TokenBridge.sol` wraps all of this behind the plain
`(token, amount, receiver, destination EVM chainId)` interface that bridge
aggregators expect.

---

## 6. Messaging — how the two halves talk

`src/core/messaging/`

### 6.1 The four contracts

```
outbound:  caller → MessageDispatcher → Gateway → MultiAdapter → [adapters] → wire
inbound:   wire → [adapter] → MultiAdapter (vote → quorum) → Gateway → MessageProcessor → handler
```

- **`MessageDispatcher`** serializes and routes. For a **local** destination it
  short-circuits straight to the handler — same-chain hub+spoke (Plume runs this
  way) pays nothing and crosses no bridge.
- **`Gateway`** batches, pays, splits inbound batches, and isolates failures.
- **`MultiAdapter`** is the quorum.
- **`MessageProcessor`** deserializes and dispatches by type.

### 6.2 `Gateway` outbound: batching and payment

Batching is transient. `withBatch(data, callbackValue, refund)` sets
`isBatching`, calls back into the caller, and every `send` during that window
appends to a transient buffer keyed by **(destination chain, pool)** rather than
sending. Two guards:

- A batch's accumulated gas limit must stay under `maxBatchGasLimit(centrifugeId)`
  or it reverts `BatchTooExpensive`.
- `_isSendingBatch` blocks reentrant batch creation.

On send, `_send` asks the adapter to `estimate` and then either pays, or — in
**unpaid mode** — records `underpaid[centrifugeId][batchHash] = {counter, gasLimit}`
and returns. `repay()` lets anyone settle it later. This is what makes
pool-subsidized flows possible: the pool need not have funded the exact message
in advance.

### 6.3 `Gateway` inbound: per-message isolation

```solidity
while (remaining.length > 0) {
    length  = messageProperties.messageLength(remaining);
    message = remaining.slice(0, length);
    require(batchPoolId == messagePoolId(message), MalformedBatch());
    requiredSource = messageSourceCentrifugeId(message);
    require(requiredSource == 0 || requiredSource == centrifugeId, SourceMismatch());
    gasLimit = messageProcessingGasLimit(localCentrifugeId, message);
    require(gasleft() >= gasLimit, NotEnoughGas());
    _safeProcess(...);   // excessivelySafeCall, gas-capped
}
```

Three checks are load-bearing:

1. **Every message in a batch must belong to the same pool.** A batch is a
   pool-scoped unit; you cannot smuggle another pool's message into one.
2. **`messageSourceCentrifugeId`** — some message types are only valid from a
   specific chain (a `PoolId` embeds its hub chain), and this rejects the rest.
3. **`excessivelySafeCall` with a gas cap and a reserve.** A single message that
   reverts or returns a huge blob **cannot take down the rest of the batch**. It is
   counted in `failedMessages[centrifugeId][messageHash]++` and can later be
   `retry`'d or written off with `clearFailedMessage`.

Note `failedMessages` is a **counter**, not a flag — the same message can
legitimately be in flight several times, and each failure is tracked separately.

### 6.4 `MultiAdapter` — quorum with sessions

```solidity
mapping(uint16 => mapping(PoolId => uint16)) activeSessionId;
mapping(uint16 => mapping(PoolId => mapping(uint16 => IAdapter[]))) adapters;
mapping(uint16 => mapping(PoolId => mapping(uint16 => mapping(IAdapter => Adapter)))) _adapterDetails;
mapping(uint16 => mapping(bytes32 voteKey => int16[8])) _votes;   // MAX_ADAPTER_COUNT = 8
```

**Sessions.** `setAdapters` increments a session id and requires the caller to
pass the expected new id (`targetSessionId`) — so a config change cannot race.
Outbound payloads are **prefixed with the session id**; inbound, votes are keyed
by session. Changing the adapter set therefore **cannot count stale votes from the
old set**. A session can also be `blockSession`'d (its config moved out of live
storage so ordinary checks reject it) and `unblockSession`'d.

**Voting.** Vote key is `keccak256(poolId, payload)` — the *whole payload
including the session prefix*. Each adapter has an index and increments its own
slot in an `int16[8]`. Threshold reached → `decreaseFirstNValues(quorum)` consumes
one vote from each and forwards **exactly once**. Because votes are counters, N
identical in-flight payloads settle as N executions, not one.

**Vote and execute are separable.** `handle()` does both; `vote()` only records;
`execute()` forwards a payload already at threshold. That matters operationally:
a slow adapter's confirmation can be submitted independently, and a pool manager
can submit on an adapter's behalf.

### 6.5 `GasService`

Per-message-type gas limits, immutable at deployment, benchmarked by
`script/checks/benchmarks.sh`. They span roughly **142k** (a plain notification)
to **2.87M** (deploy-and-link a vault), and include the adapter + gateway
overhead. Adapters use them to buy destination gas.

---

## 7. Vaults — how investors get in and out

`src/vaults/` — and this is where V3 differs most from V1/V2.

### 7.1 Two shapes

| | `AsyncVault` | `SyncDepositVault` |
|---|---|---|
| Standard | ERC-7540 (+ ERC-7887 cancel) | ERC-4626 deposit, ERC-7540 redeem |
| Deposit | request → approve → issue → claim | **immediate**, at the current valuation |
| Redeem | request → approve → revoke → claim | request → approve → revoke → claim |
| Spoke manager | `AsyncRequestManager` | `SyncManager` + `AsyncRequestManager` |
| Hub manager | an `IHubRequestManager` (e.g. `BatchRequestManager`) | — for deposits |

`SyncManager` bounds instant deposits with a per-(pool, share class, asset)
**`maxReserve`** and prices them through a pluggable `ISyncDepositValuation`.
That reserve cap is the entire liquidity-risk control on the sync path.

Multiple vaults can exist per share class — one per accepted payment asset
(ERC-7575) — all issuing the same share token.

### 7.2 Async deposit, end to end

Spoke side, `AsyncRequestManager.requestDeposit`:

```solidity
state.pendingDepositRequest += assets;
_sendRequest(vault, DepositRequest(controller, assets).serialize());
spoke.noteDeposit(poolId, scId, asset, tokenId, assets);
spoke.reserve   (poolId, scId, asset, tokenId, assets, address(this), REASON_DEPOSIT);
```

Read the `noteDeposit` + `reserve` pair carefully — it is the neatest trick in the
codebase. The assets physically land in the pool escrow, but the two queued
updates (`+assets` then `−assets`) **cancel out**, so:

- the pending subscription is **not** hub-accounted, and does not inflate NAV;
- it does **not** consume escrow withdrawal headroom;
- yet the money is genuinely in escrow, not in the vault.

On approval, `ApprovedDeposits` arrives and the manager simply **unreserves** —
and now the assets enter the hub-accounted holding, valued hub-side at the next
queue flush.

Hub side, `BatchRequestManager`:

```solidity
struct EpochId { uint32 deposit; uint32 issue; uint32 redeem; uint32 revoke; }
mapping(PoolId=>mapping(ShareClassId=>mapping(AssetId=>EpochId))) epochId;
mapping(... => mapping(uint32 epoch => EpochInvestAmounts)) epochInvestAmounts;
mapping(... => uint128) pendingDeposit;                       // aggregate
mapping(... => mapping(bytes32 investor => UserOrder)) depositRequest;   // {pending, lastUpdate}
mapping(... => mapping(bytes32 investor => QueuedOrder)) queuedDepositRequest; // {isCancelling, amount}
```

The manager calls, in order:

1. **`approveDeposits(epoch, amount, pricePoolPerAsset)`** — must match the
   current epoch exactly (`EpochNotInSequence`), must not exceed `pendingDeposit`
   (which can legitimately be less than intended because requests keep arriving
   asynchronously — the source calls this out as a race and clamps rather than
   reverting). Records the epoch snapshot, reduces pending, sends
   `ApprovedDeposits` back.
2. **`issueShares(epoch, pricePoolPerShare)`** — a *separate* epoch cursor, so
   approval and pricing are separate decisions at separate times. Sends
   `IssuedShares`; the spoke mints into the pool escrow.
3. **`notifyDeposit` / `_claimDeposit`** per investor and epoch — sends
   `FulfilledDepositRequest`, and the investor's `maxMint` / `depositPrice` are
   updated on the spoke. `maxDepositClaims` tells you how many epochs an investor
   still has to claim.

**Four independent epoch cursors** — `deposit`, `issue`, `redeem`, `revoke` — per
*(pool, share class, asset)*. Not one global clock.

### 7.3 So: does V3 have epochs?

Yes, but they are nothing like Tinlake's.

- They are **per (pool, share class, asset)**, not per pool.
- There are **four cursors**, not one, so approval and pricing decouple.
- They advance **when the manager acts**, not on a timer.
- There is **no solver**. Tinlake and V2 closed an epoch by solving a linear
  program over all orders subject to tranche ratios and reserve constraints
  (`v2/clp-wasm`). Here the manager simply names an approved amount.
- And crucially, **the whole thing is optional**: `BatchRequestManager` is one
  `IHubRequestManager` implementation registered per (pool, destination chain).
  `SyncDepositVault` bypasses it entirely.

So: epochs went from being a mandatory global settlement mechanism to being one
pluggable request-manager strategy among others.

### 7.4 Investor state on the spoke

```solidity
struct AsyncInvestmentState {
    uint128 maxMint;                       // claimable shares
    uint128 maxWithdraw;                   // claimable assets
    D18     depositPrice;                  // weighted avg, priceAssetPerShare
    D18     redeemPrice;                   // weighted avg
    uint128 pendingDepositRequest;         // assets
    uint128 pendingRedeemRequest;          // shares
    uint128 claimableCancelDepositRequest; // assets
    uint128 claimableCancelRedeemRequest;  // shares
    bool    pendingCancelDepositRequest;
    bool    pendingCancelRedeemRequest;
}
mapping(IBaseVault => mapping(address investor => AsyncInvestmentState)) investments;
```

The prices are **weighted averages across the epochs an investor's request spanned**
— which is exactly why `maxMint` (shares) and `maxDeposit` (assets) are both
needed: one converts to the other through the average price the investor actually
got, not the current price.

Cancellation is a state machine, not a delete: `pendingCancelDepositRequest` is
set, the cancel travels to the hub, and the cancelled amount comes back in
`FulfilledDepositRequest.cancelledAssetAmount` to become
`claimableCancelDepositRequest`. Requesting again while a cancel is pending
reverts (`CancellationIsPending`).

### 7.5 Who pays for the cross-chain leg

`AsyncRequestManager` draws on `SubsidyManager` (`src/utils/`), which holds
per-pool ETH in `RefundEscrow` contracts. **The pool subsidizes the investor's
cross-chain message.** An investor on Base does not need to reason about paying
for the hub-chain hop.

### 7.6 `VaultRouter`

An EOA convenience layer: permit-based approvals (ERC-2612), locked-request
tracking, multicall batching, operator endorsement. It holds assets
**transiently within itself** during multi-step operations — the source is
explicit that no funds must remain after a transaction, because leftovers are
claimable by anyone.

---

## 8. The share token and compliance

`src/token/`

### 8.1 `ShareToken`

ERC-20 + ERC-1404 + ERC-7575 share pointer. The storage layout is the design:

```solidity
struct Balance { uint128 amount; bytes16 hookData; }
mapping(address => Balance) private balances;
mapping(address asset => address) public vault;   // ERC-7575
```

**Balance and compliance state share one slot.** `hookData` is 16 bytes the hook
interprets — conventionally a `uint64` memberlist expiry in the high bytes and a
freeze bit in the low. So a transfer reads the sender's balance *and* their
compliance status in one `SLOAD`. Total supply is capped at `uint128` max so it
always fits.

Every balance change — `transfer`, `transferFrom`, `mint`, `burn` — calls
`onERC20Transfer` and **reverts with `RestrictionsFailed` unless the hook returns
its own selector**. Not a boolean: the selector, so a hook that silently returns
nothing fails closed.

`authTransferFrom` is the privileged path: a ward moves tokens with no allowance,
the hook is notified via `onERC20AuthTransfer`, and **the result is not
enforced**. That is how forced transfers, redemption pulls and cross-chain burns
work without every hook needing to special-case them.

With no hook installed the token is completely unrestricted.

### 8.2 `ShareTokenRegistrar` — the `IRegistrar` seam

Core never touches a share token directly. It goes through `IRegistrar`, which
means **an alternative share-token standard can be plugged in per share class**
without changing core.

`ShareTokenRegistrar` implements it for the protocol's own `ShareToken`:
CREATE2-deterministic deployment (address derives only from `decimals` and salt,
so `previewTokenAddress` works before deployment), stays a ward on every token it
creates, relies `Root` on each.

`burn` is the interesting exception: it **pulls tokens to the calling core
contract and burns them there**, so hooks observe the same flow shape as they did
when core held token permissions directly — with the spoke visible as the
redemption or bridge source. Compatibility preserved by construction.

`canBridge` answers the spoke's cross-chain check by **encoding the destination
`centrifugeId` as an address** and running it through the ordinary restriction
check. A neat reuse: "may this user send to chain 4?" becomes an ordinary
"may this user send to address 0x…0004?".

### 8.3 The four hooks

All extend `BaseTransferHook`, which classifies every transfer by its endpoints:

```
isDepositRequestOrIssuance · isDepositFulfillment · isDepositClaim
isRedeemRequest (to == ESCROW_HOOK_ID) · isRedeemFulfillment · isRedeemClaimOrRevocation
isCrosschainTransfer · isCrosschainTransferExecution
isPoolEscrow(addr)
```

| Hook | Policy |
|---|---|
| `FreelyTransferable` | always allow. Uses the hook seam without restricting. |
| `FreezeOnly` | freeze bit only; no memberlist. |
| `RedemptionRestrictions` | memberlist required **only to redeem**. Deposits and secondary trading are open. KYC at exit. |
| `FullRestrictions` | memberlist required to *receive* in nearly every case. Only fulfillment operations and redemption claims bypass. |

`RedemptionRestrictions` deserves a moment: it lets a restricted fund's share
token trade freely on secondary markets while still requiring identity to exit at
NAV. Together with `passthrough-vaults`, that is the **deRWA** design.

Restriction updates arrive from the hub as `UpdateRestriction` payloads carrying a
tiny sub-message: `Member(user, validUntil)`, `Freeze(user)`, `Unfreeze(user)`.

---

## 9. Valuation, NAV and price

Four layers, and they are genuinely separate — this is a place where the
modularity is real rather than rhetorical.

**1. `IValuation`** — asset → pool currency.
`IdentityValuation` (always 1.0, decimal conversion only — for stablecoins and
pegged assets) and `OracleValuation` (trusted feeders per pool/share class/asset,
quorum of 1). Set per holding at `initializeHolding`, changeable with
`updateHoldingValuation`.

**2. `Holdings`** — turns valuations into carrying value, per the amount/value
split in §4.3.

**3. `NAVManager`** (`src/hooks/accounting/`) — turns the ledger into a NAV.
Registered as `ISnapshotHook`. On `onSync` — fired only when a network's snapshot
closes — it closes out the accumulated gain and loss accounts, computes
`netAssetValue` for that network from account balances, and forwards it to the
pool's `INAVHook`. `onTransfer` keeps the figures straight when shares move
between networks.

**4. `SimplePriceManager`** — an `INAVHook` for single-share-class pools. Divides
total NAV by global issuance to get price per share and pushes it back through
`Hub.updateSharePrice`. It tracks per-network issuance *alongside* shares
transferred in and out, so that when `ShareClassManager`'s issuance moves because
of a **cross-chain transfer** rather than a subscription, the transferred amounts
are netted out instead of being double-counted. With nothing issued, price is 1:1.
It refuses any share class other than the first.

The price then flows outward: `notifySharePrice` / `notifyAssetPrice` broadcast
`NotifyPricePoolPerShare` and `NotifyPricePoolPerAsset` to every spoke, where
`SpokeRegistry` stores them as `Price { D18 price; uint64 computedAt; }`.

**Prices do not expire in core.** `Price.isValid()` is just `computedAt != 0`.
Staleness is a policy concern, not a core one — `StdHubPolicy` is where share
price updates get rate- and cap-bounded.

---

## 10. Authority: wards, guardians, policies

Three independent layers. Confusing them is the most common way to misread this
codebase.

### 10.1 Wards — protocol-level

The MakerDAO `dss` pattern, inherited through Tinlake:
`mapping(address => uint256) wards`, `rely`, `deny`, `modifier auth`. See
`src/misc/Auth.sol`. `Root` holds ward on every deployed contract.

`Root` (`src/admin/Root.sol`, 121 lines):

- `pause()` / `unpause()` — **instant**, no delay.
- `scheduleRely(target)` → `executeScheduledRely(target)` — granting a new ward
  requires waiting out `delay` (**48 hours** in production, `MAX_DELAY` 4 weeks).
- `relyContract` / `denyContract` — Root exercising its ward on others.
- `endorse` / `veto` — a separate flag for trusted system contracts (the
  `VaultRouter`, escrows) that vaults consult when deciding whether an operator
  may act for a user.

Note the asymmetry, which is the whole security posture: **defence is instant,
privilege is slow.**

### 10.2 Guardians — who may reach Root

`Root` has no external entry point. Two contracts mediate, each behind its own
Safe multisig:

| | `ProtocolGuardian` | `OpsGuardian` |
|---|---|---|
| Safe | Protocol Safe (third-party verification by Cantina) | Ops Safe |
| Can | pause, schedule/cancel upgrades, cross-chain ops, adapter config | adapter initialization, network wiring, pool creation |
| Pause | **yes**, instantly by any safe owner | **no** |
| Unpause | safe consensus only | — |

Both are at the same address on all networks (`0xCEb7…35c6` and `0x0555…0dE`).

### 10.3 Policies — pool-level, and the interesting one

Wards and guardians are *protocol* authority. **Policies are how a pool bounds its
own managers.**

`IPolicy.enforce(poolId, caller, calldata)` is called by the Hub on every guarded
method and by the Spoke on every guarded spoke call. The policy holds **no state**
— the authorization ledger lives in the registry (§4.1), so every policy shares
one audited, observable ledger.

The two sides differ deliberately:

- **`IHubPolicy.authorizationDelay(...) → uint48`** — the hub *prices* a call.
  `0` means in-policy (runs synchronously). Non-zero means it must be
  pre-authorized and aged. A **revert** means forbidden outright — it cannot even
  be authorized.
- **`ISpokePolicy`** — binary. The spoke has no local timelock; authorizations
  arrive **already matured** from the hub and are consumed from a counter ledger.

The interfaces use deliberately different method names so their selectors and
interface ids differ and neither can be read through the other's ABI. The source
says: *do not collapse them.*

`StdHubPolicy` is the reference classifier. Its dispatch table is a good read on
its own — it encodes what a fund manager should be able to do without ceremony:

- **Instant** (delay 0): cross-chain notifications, pool and share metadata,
  accounting and price writes *when they come from the configured `NAVManager` /
  `SimplePriceManager`* — with `updateSharePrice` further rate- and cap-bounded.
- **Always out of policy** (needs a matured authorization): `updateHubManager`,
  `setRequestManager`, `updateVault`, `updateCurrency`, `addShareClass`,
  `notifyShareClass`, `updateManager`, `setAdapters`, `authorizeSpokeCall`.
- **`managerCall`** is out of policy and additionally pinned *by target*: the
  configured request manager is bounded by a price check, a pause call to the
  bridging hook is instant, everything else is out of policy.
- **`setPolicy` / `setSpokePolicy`** use a longer **`escalation`** delay —
  changing the rules is harder than acting within them.
- Everything else falls through to `delay`. **Deny by default.**

And `Supervisor` (`src/managers/hub/`) closes the loop: a pool-scoped registry of
**sentinels** whose only power is to **veto** a pending authorization during its
delay window. It holds no positive power at all; it is registered as a hub
manager purely so it can reach `cancelAuthorization` on sentinels' behalf.

So the full picture for a risky pool action: *manager initiates → policy prices a
delay → the call is visible onchain for that delay → sentinels may veto → if not
vetoed and not expired, it executes.*

---

## 11. Extension points

Every one of these is a zero-default interface reference in core.

| Seam | Interface | Where core holds it | Reference implementations |
|---|---|---|---|
| Asset pricing | `IValuation` | `Holdings._holding.valuation` | `IdentityValuation`, `OracleValuation` |
| Order settlement (hub) | `IHubRequestManager` | `HubRegistry.hubRequestManager[pool][chain]` | `BatchRequestManager` |
| Order settlement (spoke) | `ISpokeRequestManager` | `SpokeRegistry.requestManager[pool]` | `AsyncRequestManager`, `SyncManager` |
| Snapshot consistency | `ISnapshotHook` | `Holdings.snapshotHook[pool]` | `NAVManager` |
| NAV consumption | `INAVHook` | `NAVManager.navHook[pool]` | `SimplePriceManager` |
| Cross-chain share transfer | `IBridgingHook` | `HubRegistry.bridgingHook[pool]` | `BridgeCircuitBreaker` |
| Transfer restrictions | `ITransferHook` | `ShareToken.hook` | the four hooks in `token/hooks/` |
| Share token standard | `IRegistrar` | `SpokeRegistry.shareClass[…].registrar` | `ShareTokenRegistrar` |
| Manager bounds | `IHubPolicy` / `ISpokePolicy` | `HubRegistry._policy` / `SpokeRegistry._policy` | `StdHubPolicy` |
| Transport | `IAdapter` | `MultiAdapter.adapters[chain][pool][session]` | LayerZero, Axelar, Chainlink CCIP, Hyperlane, Standby |
| Fee accrual | `IFeeAccrual` | `Hub.feeAccrual` | — (starter kit shows one) |
| Vault | `IBaseVault` | `SpokeRegistry._vaultDetails` | `AsyncVault`, `SyncDepositVault` |

### How an extension is configured: the `Envoy`

Extensions are configured **from the hub**, not locally, so a pool's whole
configuration lives in one place. Each extension exposes `fromHub(poolId,
payload)` (and sometimes `fromSpoke`), accepts calls **only from the `Envoy`**,
rejects value, and dispatches on a leading discriminant.

`Envoy` is 20 lines and stateless. Its entire reason to exist is in its NatSpec:
it is *"the stable `msg.sender` anchor targets bind to: the Hub redeploys every
release and must never be the anchor."* Extensions authenticate against the Envoy,
so a core release does not invalidate every extension's access control.

### Spoke-side manager toolkit

- **`OnOffRamp`** — onramping is **permissionless** once an asset is enabled
  (anyone can trigger the balance-sheet deposit after assets arrive); offramping
  is permissioned, requiring predefined relayers sending to predefined accounts.
- **`ShareManager`** — hub-driven issue/revoke for holdings tracked outside the
  protocol (e.g. investments on chains where the protocol isn't deployed). Every
  operation arrives as a hub manager call through the Envoy, so it matures through
  the hub policy; **no local wallet holds any permission**.
- **`QueueManager`** — batched submission of queued assets/shares with a minimum
  delay between syncs, to stop spam when queues can be moved permissionlessly.
- **Guards** — `ApprovalGuard`, `CircuitBreakerGuard`, `SlippageGuard`.
- **`FlashLoanHelper`**, **`AccountingToken`**.
- **`AdapterFailover`** (`managers/adapters/`) — operational failover of a pool's
  adapter set.

---

## 12. Data inventory — onchain

Every persistent mapping in core, by contract. This is the protocol's state, in
full.

### Hub chain

**`HubRegistry`**
| Key | Value |
|---|---|
| `AssetId` | `AssetInfo` (decimals, registered) |
| `PoolId` | `bytes metadata` · `AssetId currency` · `IBridgingHook bridgingHook` |
| `PoolId, address` | `bool manager` |
| `PoolId` | `PolicyInfo {IHubPolicy policy; uint64 nonce}` — one slot |
| `bytes32 authId` | `uint48 validAfter` |
| `PoolId, uint16 centrifugeId` | `IHubRequestManager` |

**`Accounting`**
| Key | Value |
|---|---|
| `PoolId, AccountId` | `Account {uint128 totalDebit; uint128 totalCredit; bool isDebitNormal; uint64 lastUpdated; bytes metadata}` |
| `PoolId` | `uint64 _poolJournalIdCounter` |
| *(transient)* | `debited`, `credited`, `_currentPoolId`, per-pool journal id |

**`Holdings`**
| Key | Value |
|---|---|
| `PoolId, ShareClassId, AssetId` | `Holding {increasedAmount; decreasedAmount; assetAmountValue; IValuation valuation}` |
| `PoolId, ShareClassId, AssetId, uint8 kind` | `AccountId` (the four slots) |
| `PoolId, ShareClassId, uint16 centrifugeId` | `Snapshot {bool isSnapshot; uint64 nonce}` |
| `PoolId, ShareClassId, uint16` | `uint32 deficitCount` |
| `PoolId, uint16` | `uint32 networkDeficitCount` |
| `PoolId` | `ISnapshotHook snapshotHook` |

**`ShareClassManager`**
| Key | Value |
|---|---|
| `bytes32 salt` | `bool` (uniqueness) |
| `PoolId` | `uint32 shareClassCount` |
| `PoolId, ShareClassId` | `bool exists` · `ShareClassMetadata {name, symbol, salt}` · `Price pricePoolPerShare` · `uint32 negativeNetworkCount` |
| `PoolId, ShareClassId` | `IssuanceCounters issuanceAcrossNetworks` |
| `PoolId, ShareClassId, uint16` | `IssuanceCounters issuancePerNetwork` |

**`BatchRequestManager`** (extension, but the biggest state holder)
| Key | Value |
|---|---|
| `PoolId, ShareClassId, AssetId` | `EpochId {deposit; issue; redeem; revoke}` · `uint128 pendingDeposit` · `uint128 pendingRedeem` |
| `…, uint32 epoch` | `EpochInvestAmounts {approvedPoolAmount; approvedAssetAmount; pendingAssetAmount; pricePoolPerAsset; pricePoolPerShare; issuedAt}` |
| `…, uint32 epoch` | `EpochRedeemAmounts {approvedShareAmount; pendingShareAmount; pricePoolPerAsset; pricePoolPerShare; payoutAssetAmount; revokedAt}` |
| `…, bytes32 investor` | `UserOrder depositRequest` / `redeemRequest` `{uint128 pending; uint32 lastUpdate}` |
| `…, bytes32 investor` | `QueuedOrder queuedDeposit` / `queuedRedeem` `{bool isCancelling; uint128 amount}` |
| `…, bytes32 investor` | `bool allowForceDepositCancel` / `allowForceRedeemCancel` |

### Spoke chain

**`SpokeRegistry`**
| Key | Value |
|---|---|
| `PoolId` | `Pool` · `ISpokeRequestManager requestManager` · `PolicyInfo` |
| `PoolId, ShareClassId` | `ShareClassDetails {share token, IRegistrar}` |
| `address token` | `TokenDetails` |
| `PoolId, address` | `bool manager` · `bool bridger` |
| `bytes32 authId` | `uint256 count` (consume-only) |
| `AssetId` ↔ `(address, tokenId)` | `AssetIdKey` / `AssetId` |
| `PoolId, ShareClassId, AssetId` | `Price pricePoolPerAsset` |
| `address vault` | `VaultDetails {poolId; scId; assetId; asset; tokenId; isLinked}` |

**`PoolEscrow`** (one per pool)
| Key | Value |
|---|---|
| `ShareClassId, asset, tokenId` | `Holding {uint128 total; uint128 reserved}` |
| `ShareClassId, reserver, reason, asset, tokenId` | `uint128` |

**`SnapshotQueue`**
| Key | Value |
|---|---|
| `PoolId, ShareClassId` | `ShareQueueAmount {delta; isPositive; queuedAssetCounter; nonce}` |
| `PoolId, ShareClassId, AssetId` | `AssetQueueAmount {deposits; withdrawals}` |

**`ShareToken`** (one per share class per chain)
| Key | Value |
|---|---|
| `address` | `Balance {uint128 amount; bytes16 hookData}` |
| `address asset` | `address vault` (ERC-7575) |

**`AsyncRequestManager`**
| Key | Value |
|---|---|
| `IBaseVault, address investor` | `AsyncInvestmentState` (10 fields, §7.4) |

**`SyncManager`**
| Key | Value |
|---|---|
| `PoolId, ShareClassId` | `ISyncDepositValuation` |
| `PoolId, ShareClassId, asset, tokenId` | `uint128 maxReserve` |

### Messaging

**`Gateway`**: `underpaid[centrifugeId][batchHash] → {counter, gasLimit}` ·
`failedMessages[centrifugeId][messageHash] → uint256` ·
`manager[poolId][address] → bool`

**`MultiAdapter`**: `activeSessionId[chain][pool]` ·
`adapters[chain][pool][session] → IAdapter[]` ·
`_adapterDetails[chain][pool][session][adapter] → {id, quorum, threshold}` ·
`_blockedSessions[chain][pool][session]` · `_votes[chain][voteKey] → int16[8]`

### Admin

**`Root`**: `wards` · `paused` · `delay` · `endorsements[address]` ·
`schedule[relyTarget] → timestamp`

---

## 13. Data inventory — the message wire format

`src/core/messaging/libraries/MessageLib.sol`. **This is the protocol's public
API across chains** — if you learn one artifact, learn this one.

Messages are packed with `abi.encodePacked`, prefixed by a one-byte
`MessageType`. Lengths are packed into two `uint256` constants
(`MESSAGE_LENGTHS_1`) rather than an if/else chain, to keep bytecode small.
Anything below `NotifyPool` in the enum is **pool-independent**; everything from
`NotifyPool` on carries its `PoolId` at offset 1, which is what lets `Gateway`
enforce "one batch, one pool" cheaply.

| # | Type | Payload |
|---|---|---|
| — | **Protocol-wide** | |
| 1 | `ScheduleUpgrade` | `target` |
| 2 | `CancelUpgrade` | `target` |
| 3 | `RegisterAsset` | `assetId, decimals` |
| 4 | `SetPoolAdapters` | `poolId, threshold, targetSessionId, adapterList[]` |
| — | **Pool & share class** | |
| 5 | `NotifyPool` | `poolId` |
| 6 | `NotifyShareClass` | `poolId, scId, name, symbol, decimals, salt, registrar, extraGasLimit, payload` |
| 7 | `NotifyPricePoolPerShare` | `poolId, scId, price, timestamp` |
| 8 | `NotifyPricePoolPerAsset` | `poolId, scId, assetId, price, timestamp` |
| 9 | `NotifyShareMetadata` | `poolId, scId, name, symbol, extraGasLimit` |
| — | **Share transfers** | |
| 10 | `InitiateTransferShares` | `poolId, scId, centrifugeId, receiver, amount, remoteExtraGasLimit, extraGasLimit, sender` |
| 11 | `ExecuteTransferShares` | `poolId, scId, receiver, amount, extraGasLimit` |
| — | **Vaults & restrictions** | |
| 12 | `UpdateRestriction` | `poolId, scId, extraGasLimit, payload` |
| 13 | `UpdateVault` | `poolId, scId, assetId, vaultOrFactory, kind, extraGasLimit, payload` |
| — | **Balance sheet** | |
| 14 | `UpdateAssets` | `poolId, scId, assetId, amount, timestamp, isIncrease, isSnapshot, nonce, extraGasLimit` |
| 15 | `UpdateShares` | `poolId, scId, shares, timestamp, isIssuance, isSnapshot, nonce, extraGasLimit` |
| — | **Investment requests** | |
| 16 | `Request` | `poolId, scId, assetId, extraGasLimit, payload` |
| 17 | `RequestCallback` | `poolId, scId, assetId, extraGasLimit, payload` |
| 18 | `SetRequestManager` | `poolId, manager` |
| — | **Manager calls & authorization** | |
| 19 | `ManagerCallFromSpoke` | `poolId, target, sender, extraGasLimit, payload` |
| 20 | `ManagerCallFromHub` | `poolId, target, extraGasLimit, payload` |
| 21 | `UpdateManager` | `poolId, kind, who, canManage` |
| 22 | `SetPolicy` | `poolId, policy` |
| 23 | `AuthorizeSpokeCall` | `poolId, payload` (the exact spoke calldata) |
| 24 | `UnauthorizeSpokeCall` | `poolId, payload` |

Two enums ride inside these:
`VaultUpdateKind {DeployAndLink, Link, Unlink}` and
`ManagerKind {Adapter, Gateway, Spoke, Bridger}`.

### Nested sub-messages

`Request`, `RequestCallback`, `UpdateRestriction` and the `ManagerCall`s carry
opaque payloads that the receiving *extension* interprets. Three of them are
protocol-defined:

**`RequestMessageLib`** — spoke → hub
```
DepositRequest(investor, amount) · RedeemRequest(investor, amount)
CancelDepositRequest(investor)   · CancelRedeemRequest(investor)
```

**`RequestCallbackMessageLib`** — hub → spoke
```
ApprovedDeposits(assetAmount, pricePoolPerAsset)
IssuedShares(shareAmount, pricePoolPerShare)
RevokedShares(assetAmount, shareAmount, pricePoolPerShare)
FulfilledDepositRequest(investor, fulfilledAssetAmount, fulfilledShareAmount, cancelledAssetAmount)
FulfilledRedeemRequest (investor, fulfilledAssetAmount, fulfilledShareAmount, cancelledShareAmount)
```

**`UpdateRestrictionMessageLib`** — hub → share token hook
```
Member(user, validUntil) · Freeze(user) · Unfreeze(user)
```

And `ManagerAction` in `IBatchRequestManager` — what a `ManagerCallFromHub` to the
batch request manager may say:
`ApproveDeposits · ApproveRedeems · IssueShares · RevokeShares ·
ForceCancelDepositRequest · ForceCancelRedeemRequest`.

> **Learning shortcut:** `sdk/src/entities/crosschainMessageDescription.ts`
> renders these into English. Decode a real payload with it before reading the
> Solidity — it's much faster.

---

## 14. Data inventory — offchain (api-v3)

`api-v3/ponder.schema.ts` — ~58 Ponder/Drizzle tables over Postgres, exposed as
GraphQL. Useful in its own right as *someone else's considered opinion about
which protocol state matters*.

**Topology & deployment**
`blockchain` · `deployment` (one row per chain, one column per core contract
address) · `smart_contract` · `smart_contract_ward`

**Pools & tokens**
`pool` · `pool_spoke_blockchain` (which chains a pool operates on) · `token`
(the share class: name, symbol, salt, `totalIssuance`, `tokenPrice`,
`tokenPriceComputedAt`) · `token_instance` (that share class **on one chain**) ·
`token_instance_position` · `token_issuance` (`ISSUE`/`REVOKE`)

**Vaults & assets**
`vault` (`kind` ∈ {Async, Sync, SyncDepositAsyncRedeem}; `status` ∈
{LinkInProgress, UnlinkInProgress, Linked, Unlinked}; `maxReserve`;
crosschain-in-progress tracking) · `asset` · `asset_registration`

**Orders — five levels of granularity, and the distinctions are instructive**
`vault_invest_order` / `vault_redeem_order` — aggregate per vault
`pending_invest_order` / `pending_redeem_order` — not yet approved
`epoch_outstanding_invest` / `epoch_outstanding_redeem` — carried across epochs
`epoch_invest_order` / `epoch_redeem_order` — one epoch's approved/issued figures
`invest_order` / `redeem_order` — per investor

**Investors**
`investor_transaction` with a 14-value type enum — the cleanest available list of
what can happen to an investor:
`DEPOSIT_REQUEST_UPDATED · REDEEM_REQUEST_UPDATED · DEPOSIT_REQUEST_CANCELLED ·
REDEEM_REQUEST_CANCELLED · DEPOSIT_REQUEST_EXECUTED · REDEEM_REQUEST_EXECUTED ·
DEPOSIT_CLAIMABLE · REDEEM_CLAIMABLE · DEPOSIT_CLAIMED · REDEEM_CLAIMED ·
SYNC_DEPOSIT · SYNC_REDEEM · TRANSFER_IN · TRANSFER_OUT`
plus `whitelisted_investor` and `investor_position_checkpoint`.

**Accounting**
`holding` · `holding_account` (typed by `holding_account_type`) · `escrow` ·
`holding_escrow` · `account`

**Cross-chain**
`crosschain_message` · `crosschain_message_queue` · `crosschain_payload` ·
`crosschain_payload_queue` · `adapter` · `adapter_wiring` ·
`adapter_participation` · `pool_adapter`

**Managers & config**
`pool_manager` · `on_off_ramp_manager` · `on_ramp_asset` · `off_ramp_address` ·
`offramp_relayer` · `merkle_proof_manager` · `policy`

**Snapshots (time series)**
`pool_snapshot` · `token_snapshot` · `token_instance_snapshot` ·
`holding_snapshot` · `holding_escrow_snapshot`

**Integration-specific**
`basin_*` (swap, debt, debt_change, fee, fee_change, redeem_request,
reconciliation_warning) — a specific integration, not core protocol.

A pattern worth copying: several tables carry a **`crosschainInProgress`** enum
plus `hubSignal*` / `spokeAck*` timestamps. Because state changes are
hub→spoke messages that take real time, the indexer models the *in-flight* state
explicitly rather than pretending writes are atomic. Any multi-chain indexer needs
this and most don't have it.

### The SDK's view

`sdk/src/entities/` is the same model, typed for application use:
`Pool` · `PoolNetwork` · `ShareClass` · `Vault` · `Investor` · `BalanceSheet` ·
`OnchainPM` · `MerkleProofManager` · `OnOffRampManager` · `Reports/` (balance
sheet, P&L, cash flow) · `crosschainMessages`. Almost every file has a `.test.ts`
beside it that doubles as a usage example.

---

## 15. Deployment topology

From `protocol/env/mainnet/`. The `centrifugeId` column is what appears inside
every `PoolId` and `AssetId`.

| Chain | EVM chainId | centrifugeId | Adapters deployed |
|---|---|---|---|
| Ethereum | 1 | 1 | LayerZero, Axelar, Chainlink |
| Base | 8453 | 2 | LayerZero, Axelar, Chainlink |
| Arbitrum | 42161 | 3 | LayerZero, Axelar, Chainlink |
| Plume | 98866 | 4 | LayerZero, Axelar, Chainlink |
| Avalanche | 43114 | 5 | LayerZero, Axelar, Chainlink |
| BNB Smart Chain | 56 | 6 | LayerZero, Axelar, Chainlink |
| HyperEVM | 999 | 9 | LayerZero, Axelar, Chainlink |
| Optimism | 10 | 10 | LayerZero, Axelar, Chainlink |
| Monad | 143 | 11 | LayerZero, Axelar, Chainlink |
| Pharos | 1672 | 12 | LayerZero, Chainlink |
| X Layer | 196 | 13 | LayerZero, Chainlink |

`connections.json` declares the mesh as rules rather than pairs:

```json
{"chains": ["ALL","ALL"],                  "adapters": ["axelar","layerZero"],   "threshold": 2}
{"chains": [["pharos"],"ALL"],             "adapters": ["layerZero"],            "threshold": 1}
{"chains": [["monad"],"ALL"],              "adapters": ["layerZero","chainlink"],"threshold": 2}
```

So the default is **2-of-2 Axelar + LayerZero**, with per-corridor overrides where
one adapter doesn't cover a chain. `env/connections_viewer.html` renders it.

Each chain file also carries `protocolAdmin` and `opsAdmin` Safe addresses, the
CREATE3 `namespace` (see `create3-gate`), a `batchLimit`, per-adapter config
(LayerZero EID and DVN settings, Axelar chain name and gas service, Chainlink
chain selector and router), the deployed contract addresses with deployment block
and version, and `deploymentInfo` naming the exact **git commit** each deployment
came from.

That last field is the point: the docs name v3.1.0's deployed commit as
`6b9d36eabee48728486f377ea2766a5cd233c555`, and Sherlock published a **deployment
verification** report against it (`docs/audits/2026-02-Sherlock-deployment.pdf`) —
a separate audit of "is the deployed bytecode the reviewed source", distinct from
auditing the source.

---

## 16. Five walkthroughs

Trace these in the code. They cover most of the protocol.

### 16.1 Launching a pool on three chains

```
OpsGuardian → Hub.createPool(poolId, admin, currency)
                └─ HubRegistry.registerPool     [poolId.centrifugeId() must == local]
Hub.addShareClass(poolId, name, symbol, salt)   [salt must be prefixed with poolId]
                └─ ShareClassManager: scId = newShareClassId(poolId, ++count)
Hub.createAccount × N                            [the accounting taxonomy]
Hub.notifyPool(poolId, chainB)      → NotifyPool       → SpokeHandler: addPool + deploy PoolEscrow
Hub.notifyShareClass(poolId, scId, chainB, registrar)
                                    → NotifyShareClass → SpokeHandler → IRegistrar deploys ShareToken (CREATE2)
Hub.updateVault(poolId, scId, assetId, factory, DeployAndLink)
                                    → UpdateVault      → SpokeHandler → factory deploys + registers + links
Hub.initializeHolding(poolId, scId, assetId, valuation, [4 accountIds])
Hub.setPolicy(poolId, stdHubPolicy)
```

All of it can be wrapped in one `Hub.multicall` inside `Gateway.withBatch`, so
each destination chain receives **one payload**. That is the "one-click
deployment" claim, and it is real.

### 16.2 An investor subscribes (async)

```
spoke chain
  investor → AsyncVault.requestDeposit(assets, controller, owner)
    AsyncRequestManager.requestDeposit:
      state.pendingDepositRequest += assets
      spoke.noteDeposit(...)  +assets queued
      spoke.reserve(...)      −assets queued   ← cancels out; not NAV-visible
      → Request{DepositRequest(investor, assets)}
hub chain
  MessageProcessor → HubHandler → HubRegistry.hubRequestManager[pool][chain]
    BatchRequestManager.request → pendingDeposit += assets, depositRequest[investor].pending += assets

  manager → approveDeposits(epoch, amount, pricePoolPerAsset)
    → RequestCallback{ApprovedDeposits}  → spoke: unreserve  → now hub-accounted
  manager → issueShares(epoch, pricePoolPerShare)
    → RequestCallback{IssuedShares}      → spoke: spoke.issue(→ pool escrow)
  manager → notifyDeposit(investor, epoch)
    → RequestCallback{FulfilledDepositRequest} → spoke: state.maxMint += shares, depositPrice updated

spoke chain
  investor → AsyncVault.mint(shares, receiver)   → escrow → receiver, hook checked
```

### 16.3 A sync deposit

```
investor → SyncDepositVault.deposit(assets, receiver)
  SyncManager: shares = valuation[pool][scId].previewDeposit(assets)
               require(escrow balance + assets <= maxReserve[...])
               spoke.deposit(...)   assets → PoolEscrow, queued +
               spoke.issue(...)     shares → receiver,   queued +
```

One transaction. No hub round-trip, no epoch, no request manager on the hub side.
The hub finds out at the next `submitQueuedAssets` / `submitQueuedShares`.

### 16.4 NAV updates and a new share price

```
manager → Hub.updateHoldingValue(poolId, scId, assetId)
  Holdings.update → live quote vs carrying value → (isPositive, diff)
  Hub._updateAccountingValue → _journal:
      gain:  debit AmountDebit    credit ValueIncrease
      loss:  debit ValueDecrease  credit AmountDebit
  Holdings.callOnSyncSnapshot(...)
      └─ only if snapshot.isSnapshot → NAVManager.onSync
            close gain/loss accounts → netAssetValue(network) → INAVHook
              └─ SimplePriceManager: NAV / issuance (net of cross-chain transfers)
                    → Hub.updateSharePrice
                        → NotifyPricePoolPerShare → every spoke
```

The gate on `isSnapshot` is the whole reason `SnapshotQueue` computes that flag.

### 16.5 A risky manager action under policy

```
manager → Hub.updateVault(...)                   // always out of policy
  _enforce → StdHubPolicy.enforce → HubRegistry.consumeAuthorization → REVERT (none)

manager → Hub.initiateAuthorization(poolId, calldata)
  policy.authorizationDelay(...) = delay  (non-zero, else InPolicy)
  authId = keccak256(poolId, policy, nonce, calldata)
  authorizedAfter[authId] = now + delay        emit AuthorizationScheduled

  … delay window: the exact calldata is public onchain …
  a sentinel may → Supervisor → Hub.cancelAuthorization  ← veto

manager → Hub.updateVault(...)  again
  _enforce → policy.enforce → consumeAuthorization
      require(now >= validAfter && now <= validAfter + expiry)
      delete authorizedAfter[authId]           emit AuthorizationConsumed
  → executes
```

---

## 17. Design decisions worth arguing with

Read the code with these in hand; they're the places where reasonable people
differ.

**Cumulative counters everywhere.** Holdings, issuance, escrow reservations, vote
tallies. It makes the system robust to reordering and rounding, at the cost that
`uint128` counters grow forever and a "current" figure is always derived. The
team clearly decided monotonic accumulate + derived-read beats
clamped-mutable-balance. Worth internalizing.

**Refusing to answer instead of reverting on write.** `totalIssuance` reverts
while negative; `NAVManager` only computes at a snapshot. Writes always succeed;
*derived reads* fail closed. This is how the system stays eventually-consistent
without global locks — but it means integrators must handle a reverting view,
which is unusual and easy to get wrong.

**Four account slots, no more.** A liability is a holding whose counterparts point
at liability-normal accounts. Elegant and extensible — but it puts real accounting
judgment in *configuration* (which `AccountId` goes in which slot) rather than in
code, so a misconfigured pool has wrong books with no contract-level error.

**Policy over calldata, not over roles.** Pre-authorizing exact bytes is maximally
precise and maximally observable. It also means a manager cannot pre-authorize
"rebalance up to X" — only one specific rebalance. Operationally heavy by design.

**Quorum but small.** 2-of-2 on the main corridors: an *and*, not an *m*-of-*n*
with slack. Either bridge halting halts that corridor. `StandbyAdapter`,
`blockSession` and `AdapterFailover` exist precisely because that trade needs an
operational escape.

**Prices don't expire in core.** Deliberate — staleness is policy. But it means
a core read of `pricePoolPerShare` carries no freshness guarantee; check
`computedAt` yourself.

**The pool subsidizes cross-chain gas.** Great UX. It also means a pool that runs
out of subsidy has investors whose requests silently sit as underpaid batches
until someone calls `repay`.

**Immutable core, mutable everything else.** The core cannot be fixed; the
extensions can be swapped. So most real risk lives in extensions and in
configuration — which is exactly where the audit history concentrates (share
manager, onchain PM, gateway, bridge, LayerZero adapter all got their own
reviews).

---

## 18. How to keep learning

**In this repo, in order:**

1. `protocol/src/README.md` → `src/core/README.md` → `src/core/{hub,spoke,messaging}/README.md`.
   Genuinely well written; better than most protocols' external docs.
2. `protocol/src/core/types/*.sol` — five short files, the whole domain model.
3. `protocol/src/core/hub/Accounting.sol` (160 lines) and `Holdings.sol` (290).
   The comments explain *why*, not what.
4. `protocol/src/core/messaging/libraries/MessageLib.sol` — the cross-chain API.
5. `sdk/src/entities/` — the same model in TypeScript, with tests as examples.
6. `api-v3/ponder.schema.ts` — what's worth indexing, and the in-flight modelling.
7. `centrifuge-starter-kit/` — write an extension.

**Run it:**
```sh
cd protocol && forge test                      # full suite
forge test --match-path 'test/**/integration/*' -vvv
cd ../sdk && pnpm i && pnpm test
```

**Then read the audits** in `protocol/docs/audits/`, newest first. The BurraSec
and yAudit reports on v3.3 will teach you the parts of the design that are
actually subtle.

**And the history**, when you want to know why: `v2/liquidity-pools/src/` as a
diff against `protocol/src/` (§2 of the V2 summary maps them), and
`v1/tinlake/src/lender/coordinator.sol` for the epoch-solver world V3 left behind.

---

*Cross-references: [`repos.md`](./repos.md) for the repository inventory ·
[`summaries/protocol.md`](./summaries/protocol.md) for the repo-level view ·
[`summaries/v2-liquidity-pools.md`](./summaries/v2-liquidity-pools.md) for the
V2→V3 diff.*
