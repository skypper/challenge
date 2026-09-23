# Q&A questions

Submit at least 6 h before the session. Ordered by how much the answer changes the build.
Each entry: the question as we would send it, why it matters, and what we do under each answer.

## Q0. What does "publish" mean?

**Ask:** "The brief says 'we track this position and publish what it is worth; counterparties
settle on that number.' What exactly is published: an on-chain value (which contract?), a daily
report, or a mark in an internal system? How often, with what fields (shares, price, NAV,
timestamp?), who computes it, and who consumes it to settle?"

**Why:** the published number is the thing the monitor protects. If it is an on-chain value Sky
writes, that contract is the primary read and the reconciliation is Sky's number vs Chronicle vs
Centrifuge's settlement price. If it is an off-chain report, the app needs it as an input and
"cannot read" includes "the report did not arrive". If they mean Centrifuge's own price push,
the current map already covers it.

**If on-chain, Sky-owned:** add that contract to the snapshot; make it the left leg of I2/I3.
**If off-chain report:** add a report input with its own freshness check; log its absence as
`no_verdict`.
**If Centrifuge's push:** no change.

## Q1. Which third-party feed?

**Ask:** "The brief says 'the price we take from a third-party feed'. Is that the Chronicle
ACRDX oracle on Ethereum (`0x9a3bF392f86acd1b1EC07d026B326302eAED7488`), or a NAV report you
receive from the fund administrator off-chain?"

**Why:** every check compares the settlement price against a reference. Chronicle is a contract
anyone can read, with full history in its `Poked` events. A fund-admin file is an input the app
has to be given, and it has no on-chain history.

**If Chronicle:** reference leg is fully automated; replay over history works.
**If a file:** add a CSV/JSON input; historical validation only covers dates for which we have
the file; note it in "what we cannot read".

## Q2. Which chain?

**Ask:** "Which chain does the position you track live on, and where do your counterparties
settle: Ethereum, or Plume where ~98.8% of ACRDX supply is (20.3M vs 0.24M shares)?"

**Why:** the Spoke, token and vault stack exist at the same addresses on both chains, but the
events, block ranges and RPC differ. Reading Ethereum when the position is on Plume is reading
the wrong book.

**If Ethereum:** as planned.
**If Plume:** swap RPC and block ranges; hub-side reads (BatchRequestManager, ShareClassManager)
stay on Ethereum because the hub is there; add Plume archive/RPC to the config.
**If both:** run the same invariants per chain, tag verdicts by chain.

## Q3. Archive access?

**Ask:** "Can we assume an archive RPC (state at historical blocks), or should historical
checks be reconstructable from events alone?"

**Why:** events are always available for the past; contract state is not. The escrow cash
identity and per-investor pending amounts are state. Without archive access they run live only.

**If archive:** replay covers I1–I5 in full.
**If not:** replay covers price and settlement (I1–I3, I4's arithmetic lines); cash-state checks
report `no_verdict: needs archive` for past blocks and run live only.

## Q4. Is the May 12 settlement known?

**Ask:** "Redeem epoch 2 on 2026-05-12 revoked 588,066 shares at pricePoolPerShare 0.36145
(payout 212,556.92 USDC) while NAV was ~1.016, with 378,868 shares issued the same day to two
new holders. Is that a known position transfer, and should a settlement-price check treat it as
an alert or as a labelled exception?"

**Why:** it is the largest deviation between execution price and NAV in the token's history,
about −64%. A monitor that fires on August will fire much harder here. Whether that is signal or
noise depends on whether Sky knew.

**If known/intended:** add an allow-list of labelled epochs; the check still records it.
**If not known:** it is a finding for the design note, and the alert stands.

## Q5. Is the empty hub ledger expected?

**Ask:** "ShareClassManager.totalIssuance for this share class reads 0 and Holdings is
uninitialised; the BalanceSheet queue on Ethereum holds an unsubmitted lifetime delta. Is the hub
ledger intentionally unused for this pool, or should it be reconciling?"

**Why:** if intentional, the "our ledger equals reality" invariant has no on-chain counterpart
and we say so. If accidental, the protocol's own reconciliation has been off since launch, which
is itself the class of problem the brief describes.

**If intentional:** I5 becomes log-only with a note.
**If accidental:** I5 is a standing alert and a headline finding.

## Q6. What price age is acceptable?

**Ask:** "The reference price is normally published T+1 on weekdays and T+3 over weekends. What
age do you and your counterparties consider acceptable before settlement should pause?"

**Why:** the freshness threshold can be calibrated from history, but the number counterparties
agreed to is the one that matters. Their answer replaces our p99-derived default.

**If they give a number:** use it as `T_age`, keep the calibrated value as a comparison in the note.
**If they do not:** use calibration (Feb–Jul p99 + 1 business day) and state that.

## Q7. (optional) Who holds the issuer key?

**Ask:** "One EOA (`0x7bf090b97f896fb77e852cc98aa52a8cb7dc02ec`) both publishes the reference
price and submits settlement transactions. Is that Centrifuge, Anemoy, or a shared operator, and
is there a Safe or policy in front of it?"

**Why:** the August gap was that key going quiet, and both price pipes depend on it. Knowing who
operates it decides whether an alert goes to Sky ops or to the issuer, and whether Tenderly
simulation of that key's pending transactions is feasible.

---

Priority: send Q1–Q3 first; they change what gets built. Q4–Q6 sharpen the design note. Q7 if
there is room.

---

## Our own best answers (2026-09-23, from `06-what-publish-means.md`)

| Q | Best answer from evidence | Confidence | Still ask? |
|---|---|---|---|
| Q0 publish | Monthly Settlement Cycle report per prime agent (`soterlabs/settlement-reports`, `reports/grove/2026-08/`: summary.md, xlsx, provenance.json). Value = shares × price + claims; revenue = Δvalue − cash inflow. Daily on-chain pilot in `soterlabs/tally`. Counterparties = Sky and Grove settling on the report. | high | yes, to confirm and to learn cut-off time |
| Q1 feed | Chronicle. Tally has a `ChroniclePip`; "chronicle points" is a revenue line; ARCHITECTURE says "Chronicle read permission is not a freshness policy". | high | briefly, to confirm the Plume oracle address |
| Q2 chain | Plume. ACRDX is venue E22, chain `plume`, "Remote position"; 12.02M shares were revoked there on Aug 10. Hub and Chronicle canonical feed stay on Ethereum. | high | yes, to confirm holder address `0x1db91ad5…` is Grove's |
| Q3 archive | Soter's Tally CI has an `archive-forks` workflow with an RPC secret, so they have archive access. Design for events first, use archive when present. | medium | yes |
| Q4 May 12 | Unknown. Grove's position is on Plume; the May 12 Ethereum event involved a different holder (`0x43d5…`). Likely not Grove's. | low | yes, lower priority |
| Q5 hub ledger | Unknown. Nothing in Soter's repos references `totalIssuance`. | low | yes |
| Q6 price age | Soter's own convention: RelayPip `hop = 1 day`; a stale mark reverts `peek` ("must stop, not guess"). Default to 1 business day. | medium | yes, for the business-day nuance |
| Q7 issuer key | Ethereum pusher `0x7bf090b9…`; Plume revoke caller `0x8ef19b8c…`. Operator unknown. | low | yes |

New question surfaced by the evidence:

**Q8. The xlsx cash figure.** "For E22 in August, summary.md shows inflow −12,263,707.47
(12,020,502 shares × 1.020232, the Centrifuge execution price), provenance.json shows
−12,283,229.22 (× 1.021857, Chronicle's Aug 10 value), and the xlsx shows −12,149,859.77
(× 1.010762). What priced the xlsx figure, and which of the three is the one counterparties
settled on?"
