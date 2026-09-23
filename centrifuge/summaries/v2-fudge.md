# `centrifuge/fudge`

| | |
|---|---|
| **URL** | https://github.com/centrifuge/fudge |
| **Tier** | V2 — chain test infrastructure |
| **Language** | Rust · **License** unrecognized (mixed Apache/GPLv3 headers) |
| **Stars** | ~22 · **Last commit** 2024-05-07 (Polkadot v1.1.0) |
| **Local size** | ~972 KB |

## What it is

**FU**lly **D**ecoupled **G**eneric **E**nvironment for Substrate chains — a
library for driving a Substrate database directly, without running a node.

It lets you load an existing chain database and do analytics at any block;
populate an empty DB from a genesis config; arbitrarily manipulate the latest
state; provide externalities; and build blocks in WASM, optionally in companion
with a relay chain so a parachain environment can be reproduced locally.

That last capability is what made it useful: it's how Centrifuge tested runtime
upgrades and XCM behaviour against **real mainnet state** before proposing a
runtime-upgrade CP.

The README opens with three warnings about breaking changes, unimplemented
paths, and unwraps where errors should propagate — take them seriously.

## Related

`v2/centrifuge-chain` (`runtime/integration-tests`), `centrifuge/mychain` (a
related "take over a live chain locally" CLI, not cloned).
