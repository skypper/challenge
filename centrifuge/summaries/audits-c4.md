# `audits/` — the Code4rena contest snapshots

Two repos from the September 2023 Code4rena contest on **Liquidity Pools V1.0**
(prize pool $60,500). Cloned because the *findings* exist nowhere else — the
`security` repo and the docs carry only the summary report.

## `2023-09-centrifuge/` — the contest scope
10★ · 2023-12-02 · ~76 MB (mostly `lib/` submodules and `discord-export/`)

A frozen snapshot of `liquidity-pools` as audited, plus:
- `scope.txt` — exactly which files were in scope, with SLOC
- `bot-report.md` — the automated findings
- `discord-export/` — the full contest Discord channel. Unusual to have, and
  genuinely useful: it is the auditors asking the developers what things mean.

## `2023-09-centrifuge-findings/` — the issues
16★ · 2023-10-11 · ~5.1 MB

Every submitted finding as a GitHub issue export, with judge labels
(High/Medium/QA/Gas, duplicate/sponsor-confirmed/disputed). Public report:
https://code4rena.com/reports/2023-09-centrifuge

## Why it matters for reading V3

The V1 findings are the clearest available record of what went wrong in the
architecture V3 replaced. Several V3 design choices — per-pool escrows,
quorum-based `MultiAdapter` sessions, split guardians, monotonic issuance
counters — read as direct answers to issues raised here or in the Spearbit
follow-ups.

## Other audits, not cloned

- **V3 (31 PDFs)** → `protocol/docs/audits/`
- **Pre-V3 (11 files)** → `security/audits/`
- Full table with links → `documentation/docs/developer/security/audits.md`
- The Sherlock/Blackthorn V3.1 competition (Nov–Dec 2025) has no public contest
  repo; only the PDF report.
