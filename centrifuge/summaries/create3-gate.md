# `centrifuge/create3-gate`

| | |
|---|---|
| **URL** | https://github.com/centrifuge/create3-gate |
| **Tier** | Official — deployment infrastructure |
| **Language** | Solidity (Foundry) · **License** MIT |
| **Stars** | 0 · **Last commit** 2026-09-03 |
| **Local size** | ~2.1 MB |

## What it is

**The most independently reusable thing Centrifuge has published recently.** A
deterministic CREATE3 deployer that splits deployment into two keys, deployed at
`0x6A7E…` across chains.

The problem it solves is specific and real: multi-chain CREATE3 makes every
deployed address derive from *one* account, so fifty contracts across ten chains
means five hundred transactions from a cold key — impractical to sign, and
dangerous to share.

| Phase | Key | Signs | Can do |
|---|---|---|---|
| `commit` | the cold one, which every address derives from | **once per chain**, independent of contract count | declares what may be deployed, in what order, by whom |
| `deploy` | a hot one, named in the commitment | once per contract | deploys exactly that — same init code, same addresses, same order, or it reverts |

The hot key can live in CI. `addressOf(namespace, salt)` answers before anything
is deployed, so a constructor argument can be the address of a contract that does
not exist yet — **on this chain or any other**. That's what makes the whole V3
mesh deployable in one pass.

Extend `DeployGateScript` and define `contracts()` once; both phases build from
the same function so commit and deploy cannot drift.

## Contents

`src/` · `script/` · `test/` · `deployments/` · `audits/` —
`2026-08-burraSec.pdf`, `2026-09-Sherlock.pdf`.

## Related

`protocol/script/deploy` and `protocol/env/` use it.
