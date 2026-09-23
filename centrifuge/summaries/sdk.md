# `centrifuge/sdk`

| | |
|---|---|
| **URL** | https://github.com/centrifuge/sdk · npm `@centrifuge/sdk` |
| **Tier** | Official — the primary client |
| **Language** | TypeScript (viem, RxJS) |
| **Stars** | ~5 |
| **License** | LGPL-3.0-only |
| **Version / last commit** | 2.3.1 · 2026-09-08 (most active repo in the org) |
| **Local size** | ~3.4 MB |

## What it is

**The fastest way to understand what V3 actually offers.** A fully typed
JavaScript/TypeScript client covering both reads and writes across every chain a
pool touches. Queries are observables (subscribe for live updates) or awaitable
promises; transactions are awaitable *or* observable so you can watch a
multi-chain flow progress step by step.

## Entities — read these as the protocol's public API

`src/entities/` is effectively a domain model of V3:

| Entity | What it covers |
|---|---|
| `Pool` | pool-level state, metadata, workflows |
| `PoolNetwork` | a pool's presence on one specific chain |
| `ShareClass` | share class state, pricing, issuance |
| `Vault` | ERC-7540 / ERC-4626 vault interaction |
| `Investor` | positions, permissions, pending requests |
| `BalanceSheet` | spoke-side deposits/withdrawals, issue/revoke |
| `OnchainPM` | the onchain portfolio-manager surface |
| `MerkleProofManager` | merkle-gated manager calls |
| `OnOffRampManager` | on/off-ramp routing |
| `Reports/` | balance sheet, P&L, cash flow |
| `crosschainMessages` | decodes in-flight cross-chain messages + human-readable descriptions |

`crosschainMessageDescription.ts` is a nice find: it turns raw `MessageLib`
payloads into English, which makes it the easiest way to learn the message
taxonomy without reading Solidity.

Nearly every entity ships a `.test.ts` beside it — the tests double as usage
examples.

## Use it

```sh
npm i @centrifuge/sdk viem
```

Docs: https://docs.centrifuge.io/developer/centrifuge-sdk/overview/ — with
task-shaped guides (invest into a vault, query pool data, manage NAV and orders,
buy/sell DeFi assets).

## Notes

- **LGPL-3.0-only**, unlike the BUSL core.
- Ships a `Dockerfile`/`docker-compose.yml` and `test-provenance.sh` — releases
  are provenance-attested on npm.
- `apps/centrifuge-app` (V2-era frontend) pins `@centrifuge/sdk` at
  `0.0.0-alpha.12`; the current app is far ahead of that and not public.

## Related

`protocol` (what it talks to), `api-v3` (what it queries for indexed data).
