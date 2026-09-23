# `centrifuge/go-substrate-rpc-client` (GSRPC)

| | |
|---|---|
| **URL** | https://github.com/centrifuge/go-substrate-rpc-client |
| **Tier** | V2-era, but **general-purpose infrastructure** |
| **Language** | Go · **License** Apache-2.0 |
| **Stars** | **~209 — the most-starred repo in the org** |
| **Last commit** | 2024-09-19 (*dynamic extrinsic signing support*) |
| **Local size** | ~6.3 MB |

## What it is

**The** Go client for Substrate. Not really a Centrifuge product at all — it is
the de-facto standard Substrate RPC library for Go and is used across the
Polkadot ecosystem by projects with no Centrifuge connection. Centrifuge built it
for `pod` and the chain tooling and kept maintaining it.

Covers SCALE codec, storage queries, extrinsic construction and signing, metadata
decoding (v11–v15), events, and subscriptions.

Its stars are the reason a naive "most popular Centrifuge repo" ranking is
misleading: GSRPC out-stars `protocol` 4:1 while being the least
Centrifuge-specific thing in the org.

## Related

`v2/chain-custom-types` (Centrifuge's own type registry for use with it),
`p2p/pod` (the original consumer), `centrifuge/gsrpc-backup` (a fork, not cloned).
