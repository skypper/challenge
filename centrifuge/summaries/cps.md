# `centrifuge/cps` — Centrifuge Proposals

| | |
|---|---|
| **URL** | https://github.com/centrifuge/cps |
| **Tier** | Official — governance record |
| **Language** | Markdown |
| **Stars** | ~9 |
| **License** | CC-BY-SA-4.0 |
| **Last commit** | 2026-09-03 (CP17 merge) |
| **Local size** | ~9.7 MB |

## What it is

**The decision log for the entire protocol.** Every Centrifuge Proposal (CP) that
has been submitted, with status (`passed` / `rejected` / `voting` / `proposed`)
in frontmatter. CP0 defines the framework itself. ~170 proposals span runtime
upgrades, treasury spending, pool onboarding, fee changes, and — critically —
the architectural pivots.

If you want to know *why* Centrifuge looks the way it does, this is the repo, not
the code.

## The CPs that explain the current shape

| CP | Why it matters |
|---|---|
| [CP141](../cps/cps/CP141/CP141.md) | **"Initiate the development of Centrifuge V3, a multi-chain, EVM based protocol."** The pivot away from Substrate. |
| [CP149](../cps/cps/CP149/CP149.md) | **CFG migration to EVM.** Deprecates chain-native CFG *and* WCFG, replaces both with a single ERC-20 on Ethereum. Mints 115M new tokens for incentives (100M vesting to Apr 2029). Post-migration supply 675M. |
| [CP108](../cps/cps/CP108/CP108.md) | Migration of onchain governance from Gov1 to OpenGov. |
| [CP28](../cps/cps/CP28.md) | Centrifuge protocol fees. |
| [CP59](../cps/cps/CP59/CP59.md) | Linked pools. |
| [CP68](../cps/cps/CP68/CP68.md) | Pool Onboarding Proposal (POP) v3 — the template every pool launch follows. |
| [CP103](../cps/cps/CP103/CP103.md) / [CP116](../cps/cps/CP116/CP116.md) | RWA lending market + its liquidity bootstrap. |
| [CP105](../cps/cps/CP105/CP105.md) | Data protocol. |
| [CP163](../cps/cps/CP163.md) | AIR→CFG swap ahead of **Altair chain deprecation** — **rejected**. The Kusama canary chain's wind-down is proposed but unresolved. |
| [CP172](../cps/cps/CP172.md) | Token-to-equity exploration — currently *proposed*, i.e. live. |

Runtime-upgrade CPs (CP26, 45, 54, 64, 73, 118, 119, 123, 159 …) are a complete
changelog of the Substrate chain, useful when reading `v2/centrifuge-chain`.

## Reading it

`README.md` is the index, split into Accepted / Rejected / Proposed. Note the
index has occasional numbering slips (e.g. the row labelled CP157 links to
`CP158.md`; `CP159.md` carries `cp: 123` in its own frontmatter) — trust the file
contents over the table.

## Related

`documentation/docs/getting-started/cfg-governance`, `cfg-token` (the CP149
implementation), `protocol` (the CP141 implementation).
