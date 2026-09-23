# Centrifuge — Repository Research Report

*Compiled 2026-09-08. All repos cloned `--depth 1` at default branch. 52 repos, ~346 MB.*

**Centrifuge** is the oldest live RWA protocol in DeFi — founded 2017, on mainnet
since 2019, zero exploits. It is infrastructure for **tokenizing and managing
real-world assets onchain**: an issuer creates a pool, tokenizes assets into it,
and distributes share tokens to investors across many chains, with NAV,
accounting and compliance handled onchain.

Everything lives under the single **[`centrifuge`](https://github.com/centrifuge)**
GitHub org — 161 repos, of which ~55 are third-party forks. There is no second org.

> **The one thing to know before reading anything:** Centrifuge has been rebuilt
> from scratch twice. Code that looks current is often two generations old. The
> `v1/`, `v2/` and `p2p/` folders here exist to make that explicit.

---

## 0. Three and a half generations

| Gen | Years | What it was | Where the code is |
|---|---|---|---|
| **P2P / POD** | 2017–2022 | Peer-to-peer exchange of business documents; only Merkle roots anchored onchain; privacy-enabled NFTs minted from field-level proofs | [`p2p/`](./p2p) |
| **V1 — Tinlake** | 2019–2023 | Ethereum securitization protocol. NFT collateral, DROP/TIN senior-junior tranches, epoch-settled orders. First RWA-backed MakerDAO facility | [`v1/`](./v1) |
| **V2 — Centrifuge Chain** | 2023–2025 | A purpose-built Substrate/Polkadot parachain held pool state; `liquidity-pools` on EVM chains let investors in. Centrifuge co-authored **ERC-7540** here | [`v2/`](./v2) |
| **V3 — Centrifuge Protocol** | 2025– | EVM-native, hub-and-spoke, multi-chain. Immutable core + modular extensions. Live on 11 chains | top level — [`protocol/`](./protocol) |

The pivot is documented, not inferred: **[CP141](./cps/cps/CP141/CP141.md)**
authorised V3; **[CP149](./cps/cps/CP149/CP149.md)** moved the CFG token off the
parachain onto Ethereum as an ERC-20.

---

## 1. The repos that matter

### Tier 1 — V3, the live protocol

| Repo | What it is | Lang | ★ | Last commit | License |
|---|---|---|---|---|---|
| [`protocol`](./protocol) | **The entire protocol.** Immutable core (hub/spoke/messaging), ERC-7540 + ERC-4626 vaults, share token + compliance hooks, 5 bridge adapters, guardians, 11 chains of deployment config, 31 audit PDFs. Read this one. | Solidity | 49 | 2026-09-03 | **BUSL 1.1** |
| [`sdk`](./sdk) | **The primary client.** Typed TS, viem + RxJS. `src/entities/` is a readable domain model of V3; also decodes in-flight cross-chain messages into English. Most active repo in the org. | TS | 5 | 2026-09-08 | LGPL-3.0 |
| [`api-v3`](./api-v3) | The Ponder/Postgres/GraphQL indexer. `ponder.schema.ts` + `src/handlers/` = an inventory of every V3 event anyone cares about. | TS | 5 | 2026-09-07 | MIT |
| [`documentation`](./documentation) | docs.centrifuge.io. Because dev happens privately, this is often the **authoritative** source for addresses, audits and the trust model. | Docusaurus | 16 | 2026-09-08 | AGPL-3.0 |
| [`cps`](./cps) | **Centrifuge Proposals** — ~170 governance decisions, the *why* behind everything. | md | 9 | 2026-09-03 | CC-BY-SA-4.0 |

### Tier 2 — V3 satellites

| Repo | What it is | Lang | ★ | Last commit | License |
|---|---|---|---|---|---|
| [`create3-gate`](./create3-gate) | **Most reusable thing here.** CREATE3 deployment split across a cold key (commits once per chain) and a hot key (deploys, and can produce nothing else). Makes the 11-chain deployment tractable. | Solidity | 0 | 2026-09-03 | MIT |
| [`passthrough-vaults`](./passthrough-vaults) | Immutable non-custodial wrapper letting a restricted vault be distributed freely — the **deRWA** mechanism. | Solidity | 1 | 2026-07-20 | BUSL 1.1 |
| [`centrifuge-starter-kit`](./centrifuge-starter-kit) | MIT-licensed worked examples of extending the core (`DepositRedeemFeeManager`). The copyable piece. | Solidity | 2 | 2026-01-09 | MIT |
| [`cfg-token`](./cfg-token) | The ERC-20 CFG + onchain delegation (adapted from the Morpho token) + `IouCfg` migration. | Solidity | 0 | 2025-04-03 | GPL-2.0+ **or** BUSL |
| [`security`](./security) | Disclosure policy + **pre-V3** audit archive (chain, liquidity-pools, POD node, Tinlake). V3 audits are in `protocol/docs/audits/`. | — | 3 | 2026-03-04 | MIT |
| [`audits/`](./audits) | Code4rena Sept-2023 contest on Liquidity Pools V1 — scope repo **and** the findings export. Includes the contest Discord log. | — | 10/16 | 2023 | — |

### Tier 3 — V2, the Substrate era (`v2/`)

| Repo | What it is | Lang | ★ | Last commit | License |
|---|---|---|---|---|---|
| [`centrifuge-chain`](./v2/centrifuge-chain) | The RWA parachain. `pallets/` is a complete inventory of what V2 could do: pools, loans, investments, oracles, permissions, rewards, LP gateway. Runtimes: `centrifuge` (Polkadot), `altair` (Kusama). | Rust | **199** | 2025-05-22 | LGPL-3.0 |
| [`liquidity-pools`](./v2/liquidity-pools) | **The direct predecessor of `protocol`.** `ERC7540Vault.sol` is the reference-grade first ERC-7540 implementation. Read as a diff against V3. | Solidity | 28 | 2025-01-13 | LGPL-3.0 |
| [`apps`](./v2/apps) | Frontend monorepo caught mid-pivot — `centrifuge-js` (Substrate client), `centrifuge-react`, `fabric` design system, onboarding/KYC API. Public work stopped Sep 2025. | TS | 34 | 2025-09-02 | LGPL-3.0 |
| [`go-substrate-rpc-client`](./v2/go-substrate-rpc-client) | **GSRPC.** The de-facto Go client for Substrate, used ecosystem-wide. Most-starred repo in the org, and the least Centrifuge-specific. | Go | **209** | 2024-09-19 | Apache-2.0 |
| [`api`](./v2/api) | SubQuery indexer for the parachain — how you query historical V2 pool data. | TS | 3 | 2025-07-21 | MIT |
| [`fudge`](./v2/fudge) | Drive a Substrate DB without a node: load mainnet state, manipulate it, build blocks in WASM against a mock relay chain. How runtime upgrades were tested. | Rust | 22 | 2024-05-07 | mixed |
| [`morpho-market`](./v2/morpho-market) | **Centrifuge × Morpho.** `PermissionedERC20Wrapper` (attestation-gated) + `VaultOracle` — how a restricted RWA token became Morpho collateral. | Solidity | 0 | 2024-07-23 | none |
| [`andromeda-payment-conduit`](./v2/andromeda-payment-conduit) | **Centrifuge × MakerDAO.** Adapter tying Maker's MIP21 output conduit to an ERC-7540 pool. | Solidity | 0 | 2024-03-25 | LGPL-3.0 |
| [`clp-wasm`](./v2/clp-wasm) | COIN-OR CLP LP solver → WASM at 100-decimal precision. **The epoch solver.** Reusable on its own. | C++ | 13 | 2021-02-07 | mixed |
| [`lp-xcm-relayer`](./v2/lp-xcm-relayer) · [`axelar-cgp-substrate`](./v2/axelar-cgp-substrate) · [`chain-custom-types`](./v2/chain-custom-types) · [`twamm`](./v2/twamm) · [`substrate-pallet-multi-account`](./v2/substrate-pallet-multi-account) · [`centrifuge-chain-functional-test`](./v2/centrifuge-chain-functional-test) | Cross-chain plumbing and odds and ends. `twamm` contains no source; `substrate-pallet-multi-account` self-declares deprecated. | | | | |

### Tier 4 — V1, Tinlake (`v1/`)

| Repo | What it is | Lang | ★ | Last commit | License |
|---|---|---|---|---|---|
| [`tinlake`](./v1/tinlake) | **The original protocol.** `borrower/` (shelf, pile, NAV feed) + `lender/` (tranche, assessor, **coordinator = epoch logic**, reserve, Maker adapter). DROP/TIN. MakerDAO `dss` lineage throughout. | Solidity | 117 | 2022-12-29 | AGPL-3.0 |
| [`tinlake-maker-lib`](./v1/tinlake-maker-lib) | MIP22 — the Centrifuge Direct Liquidation Module. The machinery behind DAI backed by real-world assets. `Properties.md` has the invariants. | Solidity | 10 | 2021-06-30 | AGPL-3.0 |
| [`tinlake-apps`](./v1/tinlake-apps) | The Tinlake frontend monorepo (UI, `tinlake.js`, onboarding, bot). Still maintained — legacy pools are live. | TS | 0 | 2025-01-09 | none |
| [`tinlake-subgraph`](./v1/tinlake-subgraph) | The Graph subgraph; `schema.graphql` is a compact V1 data model. | TS | 11 | 2024-02-22 | none |
| [`tinlake-spells-mainnet`](./v1/tinlake-spells-mainnet) | MakerDAO-style spells. `archive/` = every parameter change ever made, per pool. | Solidity | 1 | 2021-12-09 | none |
| [`tinlake-pools-mainnet`](./v1/tinlake-pools-mainnet) | Pool metadata → IPFS. The only public record of who the issuers were. | JS | 3 | 2024-12-10 | none |
| `tinlake-auth` · `tinlake-math` · `tinlake-erc20` · `tinlake-title` · `tinlake-proxy` · `tinlake-actions` · `tinlake-deploy` · `tinlake-nftfeed` · `tinlake-asset-nft` | The dapptools-style single-purpose satellites. `tinlake-auth`'s ward/rely/deny survives into `protocol/src/misc/Auth.sol`. | Solidity | 0–3 | 2020–23 | AGPL-3.0 |

### Tier 5 — the P2P / document protocol (`p2p/`)

| Repo | What it is | Lang | ★ | Last commit | License |
|---|---|---|---|---|---|
| [`pod`](./p2p/pod) | **Private Off-chain Data node.** libp2p document exchange; only Merkle roots anchored onchain. Trail of Bits audited. Where Tinlake's collateral NFTs came from. | Go | 80 | 2024-04-10 | MIT |
| [`precise-proofs`](./p2p/precise-proofs) | **Field-level Merkle proofs over protobuf.** Selective disclosure over structured data — reusable, and independent of Centrifuge. | Go | 63 | 2022-11-23 | MIT |
| [`privacy-enabled-erc721`](./p2p/privacy-enabled-erc721) | User-mintable NFTs verified against an onchain anchor registry. | Solidity | 37 | 2020 | AGPL-3.0 |
| [`zk-nft-demo-contract`](./p2p/zk-nft-demo-contract) | Same, with zkSNARKs (ZoKrates). 2019 prototype — an early applied-ZK artifact. | Solidity | 35 | 2019 | AGPL-3.0 |
| [`centrifuge-ethereum-contracts`](./p2p/centrifuge-ethereum-contracts) | Anchor + identity registries on Ethereum, before the Substrate move. | JS/Sol | 10 | 2020 | MIT |
| [`centrifuge-protobufs`](./p2p/centrifuge-protobufs) · [`invoice-unpaid-nft`](./p2p/invoice-unpaid-nft) · [`precise-proofs-js`](./p2p/precise-proofs-js) | Document schemas, the literal "unpaid invoice" NFT, a JS proof verifier. | | | | |
| [`protocol-paper`](./p2p/protocol-paper) · [`paper-privacy-enabled-nfts`](./p2p/paper-privacy-enabled-nfts) | The 2019 protocol paper and the 2018 privacy-enabled-NFT paper (LaTeX). | TeX | 3 / 8 | 2018–19 | CC-BY-SA-4.0 |

---

## 2. How the pieces fit — V3

```
 issuer / investor / integrator
        │
        ├──▶ sdk (TS, viem)  ─────────┐
        └──▶ api-v3 (Ponder GraphQL) ◀┼── indexes events from every chain
                                      │
                                      ▼
┌─────────────────────── HUB CHAIN (one, chosen per pool) ──────────────────────┐
│  Hub ─── HubHandler ─── HubRegistry ── pool/asset registry + POLICY + auths   │
│   │                         │                                                 │
│   ├── Accounting  ── double-entry, reverts if debits ≠ credits                │
│   ├── Holdings    ── canonical ledger, one IValuation per holding             │
│   └── ShareClassManager ── monotonic issued/revoked counters per network      │
│         ▲                                                                     │
│         │ extensions (all opt-in, core never depends on them):                │
│         └── managers/hub/Supervisor · hooks/accounting/{NAVManager,            │
│             SimplePriceManager} · valuations/{Identity,Oracle} ·               │
│             policies/hub/StdHubPolicy                                         │
└───────────────────────────────┬───────────────────────────────────────────────┘
                                │  MessageDispatcher → Gateway (batch + pay)
                                │  → MultiAdapter (quorum of N, numbered session)
        ┌───────────────────────┼───────────────────────┐
        │  LayerZero  Axelar  Chainlink  Hyperlane  Standby
        ▼                       ▼                       ▼
┌────────── SPOKE CHAIN ─────┐ ┌──── SPOKE ────┐ ┌──── SPOKE ────┐  … 11 live
│ Spoke ─ SpokeHandler ─ SpokeRegistry                            │
│   ├── PoolEscrow      per pool, per share class, w/ reservations│
│   ├── SnapshotQueue   nets deltas locally, flushes one msg      │
│   ├── ShareToken (ERC-20 + ERC-1404) via ShareTokenRegistrar    │
│   │     └── hooks: FreezeOnly · RedemptionRestrictions ·        │
│   │               FullRestrictions · FreelyTransferable         │
│   ├── vaults: AsyncVault (7540) · SyncDepositVault (4626)       │
│   │           AsyncRequestManager · BatchRequestManager ·       │
│   │           SyncManager · VaultRouter                         │
│   └── managers/spoke: OnOffRamp · QueueManager · ShareManager ·  │
│                       FlashLoanHelper · guards/*                │
└──────────────────────────────────────────────────────────────────┘

 governance:  Safe(Protocol) ─▶ ProtocolGuardian ─┐
              Safe(Ops)      ─▶ OpsGuardian ──────┴─▶ Root ─(48h timelock)─▶ ward on everything
```

**The same concepts appear at three layers** — read them together:

| Concept | Solidity | TypeScript client | Indexer |
|---|---|---|---|
| message taxonomy | `protocol/src/core/messaging/libraries/MessageLib.sol` | `sdk/src/entities/crosschainMessages.ts` | `api-v3/src/handlers/gatewayHandlers.ts` |
| pool / share class | `core/hub/HubRegistry.sol`, `ShareClassManager.sol` | `sdk/src/entities/{Pool,ShareClass}.ts` | `api-v3/ponder.schema.ts` |
| vault requests | `vaults/AsyncRequestManager.sol` | `sdk/src/entities/Vault.ts` | `api-v3/src/handlers/vaultHandlers.ts` |
| balance sheet | `core/spoke/Spoke.sol` + `SnapshotQueue.sol` | `sdk/src/entities/BalanceSheet.ts` | `api-v3/src/handlers/balanceSheetHandlers.ts` |

---

## 3. Suggested reading order

**If you want to understand V3 (most people):**

1. `protocol/src/README.md`, then `src/core/README.md` — the map and the
   immutable-core thesis. These sub-READMEs are better than most protocols' docs.
2. `protocol/src/core/{hub,spoke,messaging}/README.md` — in that order. Each ends
   with a rendered `.svg` in `docs/architecture/`.
3. `protocol/src/core/messaging/libraries/MessageLib.sol` — the authoritative list
   of everything the protocol can do across chains.
4. `sdk/src/entities/` — the same model in TypeScript, with tests as examples.
   `crosschainMessageDescription.ts` translates raw messages into English.
5. `documentation/docs/developer/security/guardian.md` — where the trust is.
6. `protocol/env/mainnet/*.json` + `connections.json` — what is actually deployed.
7. `centrifuge-starter-kit/` — write your first extension.

**If you want the history:**

1. `documentation/docs/getting-started/introduction/mission-and-history/`
2. `v1/tinlake/src/lender/coordinator.sol` — epoch settlement, the idea V3 dropped.
3. `v2/liquidity-pools/src/ERC7540Vault.sol` — the first ERC-7540.
4. `v2/centrifuge-chain/pallets/` — read the directory listing as a feature list.
5. `p2p/precise-proofs/README.md` — the original idea, still the best one.
6. `cps/README.md` → CP141 → CP149.

**If you're auditing:** `audits/2023-09-centrifuge-findings/` first (what broke in
V1), then `protocol/docs/audits/` chronologically, then
`protocol/{echidna,medusa}*` for the invariant suites.

---

## 4. Things worth flagging

- **Licensing is layered.** `protocol` and `passthrough-vaults` are **BUSL 1.1**
  (Licensor: Centrifuge Network Foundation; Change License GPL-3.0-or-later;
  Change Date = 5 years from publication *or* 2 years from a version's first
  public release, whichever is sooner; additional grants at
  `license.centrifuge.io`). But **`src/misc` and every `interfaces/` file are
  GPL-2.0-or-later**, and `centrifuge-starter-kit`, `create3-gate`, `api-v3`,
  `security` are MIT — those are the pieces you can reuse freely. `sdk` is LGPL-3.0.
- **Development is private.** `protocol` lands as squashed syncs from a
  `protocol-internal` repo (latest: `v3.3.0-rc1`). Public history is
  release-granular — you cannot bisect to a PR discussion. Same pattern as Ondo.
- **The current app frontend is not public.** `apps` stops at Sep 2025 and pins
  `@centrifuge/sdk@0.0.0-alpha.12`; the SDK is at 2.3.1. Assume app.centrifuge.io
  is closed source now.
- **Star counts mislead badly here.** GSRPC (209) is a generic Substrate library;
  `centrifuge-chain` (199) is a superseded generation; `protocol` — the live
  protocol on 11 chains — has 49.
- **The Substrate chain is in an unresolved wind-down.** CFG migrated to Ethereum
  ([CP149](./cps/cps/CP149/CP149.md)) and `main` stops at May 2025, but the chain
  still runs. Altair's (Kusama) deprecation was proposed and the accompanying
  AIR→CFG swap **rejected** ([CP163](./cps/cps/CP163.md)) — so the canary chain's
  fate is open.
- **Epochs changed meaning.** V1 and V2 closed one global epoch per pool by
  solving a linear program over all orders (`v2/clp-wasm`). V3 still has epochs —
  but four independent cursors (deposit/issue/redeem/revoke) per *(pool, share
  class, asset)*, advanced when a manager acts rather than on a timer, with no
  solver; and the whole thing is an **opt-in** `IHubRequestManager`
  (`BatchRequestManager`) that `SyncDepositVault` bypasses entirely. Carrying
  V1/V2 intuitions across will mislead you in both directions.
- **No meaningful third-party ecosystem to clone.** GitHub search for
  "centrifuge" is dominated by the unrelated Centrifugo real-time messaging
  library and a metagenomics classifier of the same name. Unlike most protocols,
  there is effectively no community SDK/bot layer here — Centrifuge's users are
  institutions, not retail bot operators.
- **Two things here are worth stealing regardless of Centrifuge:**
  `create3-gate` (cold/hot key split for deterministic multi-chain deploys) and
  `p2p/precise-proofs` (field-level Merkle proofs over protobuf).
- **Disk.** `audits/2023-09-centrifuge` ~76 MB, `v2/centrifuge-chain` ~56 MB,
  `protocol` ~46 MB, `documentation` ~29 MB, `v2/apps` ~23 MB. Total ~346 MB.
- **Deliberately not cloned:** ~55 third-party forks in the org — `polkadot-sdk`
  (316 MB), `polkadot-js-api` (424 MB), `metadata-portal` (616 MB),
  `defillama-server` (634 MB), `DefiLlama-Adapters`, `substrate`, `polkadot`,
  `Acala`, `interbtc`, `HydraDX-node`, `chopsticks`, `aave-protocol-v2`,
  `openzeppelin-community-contracts`, `ChainBridge` and friends. Also skipped:
  dead microrepos (`radial`, `k-radial`, `go-wasm-runtime`, `nix-templates`,
  `substrate-builder`, gatsby templates), archived frontends (`tinlake-ui`,
  `tinlake.js` — both contained in `v1/tinlake-apps` — `axis`, `gateway`,
  `tinlake-solver-ui`, `tinlake.info`), and the faucet/CLI/staking-UI odds.

---

## 5. Per-repo summaries

One file per repository (or coherent group) in [`summaries/`](./summaries):

| V3 | V2 | V1 & earlier |
|---|---|---|
| [protocol](./summaries/protocol.md) | [centrifuge-chain](./summaries/v2-centrifuge-chain.md) | [tinlake](./summaries/v1-tinlake.md) |
| [sdk](./summaries/sdk.md) | [liquidity-pools](./summaries/v2-liquidity-pools.md) | [tinlake satellites](./summaries/v1-tinlake-satellites.md) |
| [api-v3](./summaries/api-v3.md) | [apps](./summaries/v2-apps.md) | [pod](./summaries/p2p-pod.md) |
| [documentation](./summaries/documentation.md) | [api](./summaries/v2-api.md) | [precise-proofs](./summaries/p2p-precise-proofs.md) |
| [cps](./summaries/cps.md) | [go-substrate-rpc-client](./summaries/v2-go-substrate-rpc-client.md) | [the rest of the P2P era](./summaries/p2p-others.md) |
| [create3-gate](./summaries/create3-gate.md) | [fudge](./summaries/v2-fudge.md) | |
| [passthrough-vaults](./summaries/passthrough-vaults.md) | [integrations & satellites](./summaries/v2-integrations.md) | |
| [centrifuge-starter-kit](./summaries/centrifuge-starter-kit.md) | | |
| [cfg-token](./summaries/cfg-token.md) | | |
| [security](./summaries/security.md) | | |
| [audits/ (Code4rena)](./summaries/audits-c4.md) | | |

**Deep dive:** [`ARCHITECTURE.md`](./ARCHITECTURE.md) — a full walkthrough of V3's
design, control flow and data model, written to be read start to finish.

## 6. External references

- Docs: https://docs.centrifuge.io · App: https://app.centrifuge.io
- Deployments: https://docs.centrifuge.io/developer/protocol/deployments/
- Audits: https://docs.centrifuge.io/developer/protocol/security/
- Governance forum: https://gov.centrifuge.io · Proposals: [`cps/`](./cps)
- Bug bounty ($250k, Cantina): https://cantina.xyz/bounties/6cc9d51a-ac1e-4385-a88a-a3924e40c00e
- Org: https://github.com/orgs/centrifuge/repositories
- Legacy Tinlake: https://legacy.tinlake.centrifuge.io
