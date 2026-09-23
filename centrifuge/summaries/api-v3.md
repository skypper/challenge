# `centrifuge/api-v3`

| | |
|---|---|
| **URL** | https://github.com/centrifuge/api-v3 |
| **Tier** | Official — the V3 indexer |
| **Language** | TypeScript ([Ponder](https://ponder.sh/) + Drizzle + Postgres) |
| **Stars** | ~5 |
| **License** | MIT |
| **Version / last commit** | 4.4.1 · 2026-09-07 |
| **Local size** | ~2.9 MB |

## What it is

The GraphQL indexer behind Centrifuge V3 — the data source for the app, the SDK's
query layer, and anyone doing analytics. Ponder subscribes to EVM logs across
every chain the protocol runs on and maintains a Postgres model of pools, share
classes, vaults, holdings, investors, and cross-chain messages.

## Architecture

The README states the split cleanly, and it's worth respecting when reading:

- **`src/handlers/`** — thin Ponder entry points. Subscribe to logs, decode
  `event.args`, delegate. One file per protocol module: `hubHandlers`,
  `spokeHandlers`, `vaultHandlers`, `holdingsHandlers`, `gatewayHandlers`,
  `multiAdapterHandlers`, `shareClassManagerHandlers`, `balanceSheetHandlers`,
  `batchRequestManagerHandlers`, `merkleProofManagerHandlers`,
  `onOffRampManagerHandlers`, `syncManagerHandlers`, `tokenInstanceHandlers`,
  `vaultRegistryHandlers`, `poolEscrowFactoryHandlers`, `hubRegistryHandlers`,
  `handleRelyDeny` (ward changes), plus `skyHandlers` / `basinHandlers` for
  specific integrations and `blockHandlers` / `setupHandlers`.
- **`src/services/`** — the domain + persistence layer. Each service wraps one
  table as `class X extends Service<typeof Table>`.

`ponder.schema.ts` is the whole data model in one file — the best single artifact
for understanding what V3 state is worth tracking. `src/chains.ts` +
`src/contracts.ts` enumerate the deployment surface; `abis/` holds the ABIs.

## Why it's useful for research

The handler list is a **de-facto inventory of every event V3 emits that anyone
cares about**. Cross-reference it against `protocol/src/**/interfaces/*.sol` to
see which events are load-bearing versus decorative.

## Run it

```sh
pnpm i && pnpm dev      # predev spins up Postgres 16 via docker compose
```
Node 22+, pnpm, Docker.

## Related

`sdk` (consumer), `protocol` (source of events), `v2/api` (the SubQuery-based
predecessor that indexed the Substrate chain).
