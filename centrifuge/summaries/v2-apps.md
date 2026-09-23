# `centrifuge/apps` — the V2-era frontend monorepo

| | |
|---|---|
| **URL** | https://github.com/centrifuge/apps |
| **Tier** | V2 — transitional, no longer the live app's source |
| **Language** | TypeScript (Vite, React) · **License** LGPL-3.0 |
| **Stars** | ~34 · **Last commit** 2025-09-02 |
| **Local size** | ~23 MB |

## What it is

The monorepo behind app.centrifuge.io during the Substrate era, caught mid-pivot.

```
centrifuge-app/     the React app (Vite)
centrifuge-js/      JS client for Centrifuge Chain (polkadot.js based)
centrifuge-react/   React bindings/hooks over centrifuge-js
fabric/             Fabric — Centrifuge's design system
onboarding-api/     KYC/KYB onboarding backend
pinning-api/        IPFS pinning for pool metadata
faucet-api/         testnet faucet
simulation-tests/
```

`centrifuge-app/package.json` depends on **both** `@centrifuge/centrifuge-js`
(V2/Substrate) and `@centrifuge/sdk@0.0.0-alpha.12` (V3) — a snapshot of the
transition. The current V3 app is far past that alpha and is **not public**;
public work here stopped in September 2025.

## Why keep it

- `centrifuge-js` is the most complete public client for the **Substrate**
  protocol — pools, loans, tranches, permissions, rewards — and there is no V3
  equivalent to it for that chain.
- `fabric/` is a genuine, standalone design system.
- `onboarding-api/` shows the real KYC/KYB flow behind permissioned pools, which
  the contracts only hint at via memberlists.

## Related

`sdk` (the V3 replacement for `centrifuge-js`), `v1/tinlake-apps` (the Tinlake-era
equivalent), `v2/api`.
