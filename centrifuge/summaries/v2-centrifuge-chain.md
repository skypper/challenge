# `centrifuge/centrifuge-chain` — the Substrate parachain

| | |
|---|---|
| **URL** | https://github.com/centrifuge/centrifuge-chain |
| **Tier** | V2 — superseded, still running |
| **Language** | Rust (Substrate / Polkadot SDK) |
| **Stars** | **~199** — the most-starred first-party Centrifuge repo |
| **License** | LGPL-3.0 (mixed GPLv3/Apache per-file headers) |
| **Last commit** | 2025-05-22 (`main`) — *Upstream internal CFG v0.15.5 release* |
| **Local size** | ~56 MB |

## What it is

Centrifuge V2: a **purpose-built layer-1 for real-world assets**, a Polkadot
parachain. For ~2023–2025 this *was* Centrifuge — pools, loans, NAV, tranching
and permissions all lived in runtime pallets, and EVM chains reached them through
`liquidity-pools`. V3 inverted that: the protocol moved onto EVM and the chain
became a legacy component.

## The pallets are the product

`pallets/` is the clearest inventory of what V2 could do:

| Group | Pallets |
|---|---|
| Pools | `pool-system`, `pool-registry`, `pool-fees`, `loans`, `investments`, `foreign-investments`, `interest-accrual`, `order-book` |
| Pricing | `oracle-feed`, `oracle-collection` |
| Permissions | `permissions`, `restricted-tokens`, `restricted-xtokens`, `transfer-allowlist`, `collator-allowlist` |
| Cross-chain | `liquidity-pools`, `liquidity-pools-gateway`, `liquidity-pools-gateway-queue`, `liquidity-pools-forwarder`, `axelar-router`, `bridge`, `ethereum-transaction` |
| Rewards | `rewards`, `liquidity-rewards`, `block-rewards` |
| Legacy P2P | `anchors`, `anchors-v2`, `keystore`, `fees`, `nft` plumbing |
| Migration | `cfg-migration` ← the CP149 CFG→EVM path |
| Misc | `token-mux` |

`runtime/` holds three: **`centrifuge`** (Polkadot mainnet), **`altair`** (Kusama
canary), `development`, plus `runtime/common` and `runtime/integration-tests`.

## Status — read this before assuming it's live

- **Chain-native CFG is deprecated.** [CP149](../cps/cps/CP149/CP149.md) migrated
  governance and the token to an ERC-20 on Ethereum; `pallets/cfg-migration` is
  the onramp.
- **Altair (Kusama) deprecation is proposed but unresolved.**
  [CP163](../cps/cps/CP163.md), which would have set an AIR→CFG swap rate ahead of
  the wind-down, was **rejected**.
- Public `main` stops at May 2025 (runtime 1550-era). Runtime-upgrade CPs in
  `cps/` are the changelog.

## Building

Nix flake (`flake.nix`) or the `docker/` setup; `rust-toolchain.toml` pins the
compiler. Expect a long build — this is a full parachain node.

## Related

`v2/liquidity-pools` (its EVM counterpart), `v2/fudge` (test harness for it),
`v2/go-substrate-rpc-client` + `v2/chain-custom-types` (Go clients),
`v2/api` (SubQuery indexer), `p2p/pod` (which anchors documents to it).
