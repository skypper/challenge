# `centrifuge/security`

| | |
|---|---|
| **URL** | https://github.com/centrifuge/security |
| **Tier** | Official — historical audit archive + disclosure policy |
| **Stars** | ~3 · **License** MIT · **Last commit** 2026-03-04 |
| **Local size** | ~6.5 MB |

## What it is

The vulnerability-disclosure policy plus an archive of **pre-V3** audit PDFs.
Small, but it holds reports that exist nowhere else in the org.

```
audits/
├── chain/            chainbridge-audit-2020-04.pdf
│                     LA-Centrifuge-Chain.pdf          (Least Authority)
│                     SRLabs-baseline-report_2022.pdf
├── liquidity-pools/  2023-09-Code4rena.md
│                     2023-09-SRLabs.pdf
│                     2023-10-Spearbit-Cantina-Managed.pdf
│                     2024-07-Spearbit.pdf
├── node/             Trail-of-Bits-Audit.pdf          (the POD/P2P node)
└── tinlake/          dapp-org-tinlake-lender.html
                      LA-Tinlake-Audit-v0.2.5.pdf
                      LA-Tinlake-Audit-v0.3.0.pdf
```

## Read it alongside

- **V3 audits are not here** — they live in `protocol/docs/audits/` (31 PDFs) and
  are tabulated in `documentation/docs/developer/security/audits.md`.
- The Least Authority Tinlake and Chain reports are the only substantive public
  security review of the V1/V2 stacks; nothing equivalent was re-done when those
  systems were wound down.

## Bug bounty

$250,000 program on Cantina (per the docs' security overview), plus real-time
onchain monitoring via Hypernative. Contact: `security@centrifuge.io`.
