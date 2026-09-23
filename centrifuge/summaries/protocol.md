# `centrifuge/protocol` — Centrifuge V3

| | |
|---|---|
| **URL** | https://github.com/centrifuge/protocol |
| **Tier** | Official — the live protocol core |
| **Language** | Solidity (Foundry) |
| **Stars** | ~49 (badly understarred relative to importance) |
| **License** | **BUSL 1.1** (`src/misc` + all `interfaces/` files are `GPL-2.0-or-later`) |
| **Last commit** | 2026-09-03 — `Sync: v3.3.0-rc1 from protocol-internal` |
| **Local size** | ~46 MB |

## What it is

**The whole of Centrifuge V3.** Everything the protocol does onchain lives in this
one repo: the immutable core, the vaults, the share token, the cross-chain
messaging layer and its adapters, the governance/guardian contracts, and the
per-chain deployment inputs. Live on **11 mainnets** (Ethereum, Base, Arbitrum,
Avalanche, Plume, BNB Smart Chain, Optimism, HyperEVM, Monad, Pharos, X Layer)
with **33+ security reviews** and no exploits since 2019.

If you read one Centrifuge repo, read this one.

## Hub-and-spoke, in one paragraph

A pool picks **one hub chain** and operates on **many spoke chains**. The hub
holds the control plane — double-entry accounting, the holdings ledger, share
class state, NAV and price broadcast, manager permissions — and never custodies
user assets. Each spoke is a complete local deployment: it issues the ERC-20
share token, custodies assets in a pool-scoped `PoolEscrow`, and runs vaults.
State moves between them through `messaging`, which batches per (destination,
pool) and only accepts an inbound payload once a **quorum of independent
adapters** agrees on the identical bytes.

## Layout

```
src/
├── core/              THE IMMUTABLE CORE — nothing here can be upgraded
│   ├── hub/           Hub, HubHandler, HubRegistry, Holdings,
│   │                  Accounting (double-entry), ShareClassManager
│   ├── spoke/         Spoke, SpokeHandler, SpokeRegistry, SnapshotQueue,
│   │                  PoolEscrow (+ factory)
│   ├── messaging/     Gateway (batching + onchain fee settlement),
│   │                  MultiAdapter (quorum), MessageDispatcher/Processor,
│   │                  MessageLib
│   ├── types/         PoolId, ShareClassId, AssetId, AccountId, RequestId
│   ├── libraries/     PricingLib
│   └── utils/         BatchedMulticall, Envoy
├── vaults/            AsyncVault (ERC-7540), SyncDepositVault (ERC-4626),
│                      AsyncRequestManager, BatchRequestManager, SyncManager,
│                      VaultRouter, factories
├── token/             ShareToken (ERC-20 + ERC-1404), ShareTokenRegistrar,
│                      hooks/ FreezeOnly · RedemptionRestrictions ·
│                      FullRestrictions · FreelyTransferable
├── adapters/          LayerZero, Axelar, Chainlink CCIP, Hyperlane, Standby
├── admin/             Root (holds ward on everything), ProtocolGuardian,
│                      OpsGuardian, GasService
├── managers/          Extension managers — hub/Supervisor; spoke/OnOffRamp,
│                      QueueManager, ShareManager, FlashLoanHelper,
│                      AccountingToken, guards/{Approval,CircuitBreaker,Slippage}
├── hooks/             accounting/NAVManager, SimplePriceManager;
│                      bridge/BridgeCircuitBreaker
├── policies/          hub/StdHubPolicy — bounds what a pool's managers may do
├── valuations/        IdentityValuation, OracleValuation
├── bridge/            TokenBridge (burn-and-mint share transfer)
├── utils/             SubsidyManager, RefundEscrow (+ factory)
├── misc/              Auth, ERC20, Escrow, Multicall, D18, math/cast/transient
│                      libraries — GPL-licensed, reusable
└── deployment/        ActionBatchers, RootFixes
```

## Key things to read

The sub-`README.md` files are unusually good — better than most protocol docs.
Read them in this order:

1. `src/README.md` — the map.
2. `src/core/README.md` — why core is immutable and everything else is opt-in.
3. `src/core/hub/README.md` — accounting, holdings, the policy/authorization
   ledger, and why issuance is tracked as monotonic counters rather than a net.
4. `src/core/spoke/README.md` — escrow reservations, the snapshot queue, and how
   the two sides deliberately mirror (`Spoke`↔`Hub`, `SpokeHandler`↔`HubHandler`,
   `SpokeRegistry`↔`HubRegistry`, `SnapshotQueue`↔`Holdings`).
5. `src/core/messaging/README.md` — batching, onchain fee settlement, the
   `MultiAdapter` quorum + session model, and failed-message retry.
6. `docs/architecture/*.svg` — rendered PlantUML for each module.

Then: `src/core/messaging/libraries/MessageLib.sol` is the single authoritative
list of every cross-chain message type — the best index of what the protocol can
actually do.

## Deployments & audits, in-repo

- `env/mainnet/*.json` — one file per live chain, plus `connections.json`.
  `env/connections_viewer.html` renders the adapter mesh.
- `docs/audits/` — **31 reports** committed as PDFs, 2023-09 through 2026-08
  (BurraSec, Sherlock, Spearbit/Cantina, yAudit, xmxanuel, Recon, SRLabs,
  Code4rena, plus a Sherlock *deployment verification*).

## Fuzzing / formal

`echidna.yaml`, `echidna-messaging.yaml`, `medusa.json`, `slither.config.json`,
`snapshots/` (gas), `src-ir/`. Recon (Alex the Entreprenerd) ran invariant
campaigns in 2025-01 and 2025-04.

## Build

```sh
forge test          # everything
forge build
forge snapshot
```

## Caveats

- **BUSL 1.1.** Licensor is the Centrifuge Network Foundation; Change License is
  GPL-3.0-or-later; Change Date is five years from publication *or* the second
  anniversary of a given version's first public release, whichever comes first.
  Additional use grants live at `license.centrifuge.io`. `src/misc` and every
  `interfaces/` file are GPL-2.0-or-later and freely reusable.
- **Development happens in a private `protocol-internal` repo** and lands here as
  squashed release syncs. Public history is release-granular, not PR-granular —
  don't expect to bisect a bug to a review comment.

## Related

`sdk` (TS client), `api-v3` (indexer), `centrifuge-starter-kit` (how to write an
extension), `passthrough-vaults` + `create3-gate` (satellites), `documentation`.
Predecessor: `v2/liquidity-pools`.
