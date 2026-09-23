# `centrifuge/documentation`

| | |
|---|---|
| **URL** | https://github.com/centrifuge/documentation → https://docs.centrifuge.io |
| **Tier** | Official — canonical docs |
| **Language** | Docusaurus (TypeScript/MDX) |
| **Stars** | ~16 |
| **License** | AGPL-3.0 |
| **Last commit** | 2026-09-08 (updated daily) |
| **Local size** | ~29 MB |

## What it is

The source of docs.centrifuge.io, and — because Centrifuge's protocol repo is
BUSL and its development is private — **often the fastest authoritative answer**
for deployed addresses, audit history, governance structure, and the trust model.

## Where the value is

```
docs/
├── developer/
│   ├── protocol/        overview · architecture (hub/spoke/vaults/messaging)
│   │                    features (chain-abstraction, modularity, vaults,
│   │                    token-compliance, onchain-accounting)
│   │                    guides/ (create a pool, deploy vaults, invest,
│   │                    publish NAV & oracles, bridge share tokens, ...)
│   │                    integration-patterns/ · managers/ · composability/
│   │                    deployments/   ← every mainnet address, per chain
│   ├── security/        audits.md ← the full 33-review table
│   │                    guardian.md ← Root / ProtocolGuardian / OpsGuardian
│   │                    pool-access-levels.md · application-security.md
│   │                    operational-security.md
│   ├── centrifuge-sdk/  task-shaped SDK guides
│   ├── centrifuge-api/  the indexer's GraphQL surface
│   └── legacy/          pod · tinlake · querying-v2-data
├── getting-started/     mission-and-history · token-summary (CFG tokenomics)
│                        cfg-governance · glossary
│                        legacy/centrifuge-v1 (Tinlake) · legacy/centrifuge-v2
└── user/                curator · manager · investor workflows
```

## Three files worth opening first

- `docs/developer/protocol/deployments/index.mdx` — the address book. Names the
  reviewed commit for each deployed version (e.g. v3.1.0 =
  `6b9d36eabee48728486f377ea2766a5cd233c555`, verified by Sherlock).
- `docs/developer/security/guardian.md` — where the trust actually sits: `Root`
  holds ward over everything, reachable only through two guardian contracts
  behind separate Safes and a **48-hour timelock**. `ProtocolGuardian` can pause
  instantly; `OpsGuardian` cannot pause at all.
- `docs/getting-started/legacy/centrifuge-v{1,2}/index.md` — Centrifuge's own
  account of what V1 and V2 were, which is what makes the `v1/` and `v2/`
  folders here legible.

## Related

Everything. `security` (older audit PDFs), `cps` (the governance decisions the
docs describe).
