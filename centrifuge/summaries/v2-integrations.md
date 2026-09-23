# V2 integrations & satellites

Small repos around the Substrate/Liquidity-Pools era. Grouped because none needs
a page of its own, but several document integrations that are otherwise invisible.

## `morpho-market` — Centrifuge × Morpho RWA market
0★ · Solidity · no license file · 2024-07-23

Contracts for the RWA Morpho market. Two pieces:
- **`PermissionedERC20Wrapper`** — an ERC-20 wrapper mintable/transferable only to
  accounts holding *verified account* and *non-US verified country* attestations
  (Coinbase-style onchain attestations), or manually memberlisted. Extends
  Morpho's `erc20-permissioned`.
- **`VaultOracle`** — a Morpho-compatible oracle for ERC-4626 vaults.

Audited (see `audits/`). This is how a permissioned RWA tranche token became
usable as Morpho collateral — the concrete answer to "how does a restricted token
compose with permissionless DeFi".

## `andromeda-payment-conduit` — Centrifuge × MakerDAO
0★ · Solidity · LGPL-3.0 · 2024-03-25

Adapter acting as `mate` and `operator` of the output conduit of MakerDAO's
**MIP21 RWA toolkit**. It ties Maker's bookkeeping to a Centrifuge ERC-7540 pool:
DAI is swapped to `gem` (e.g. USDC), pushed into the adapter, and a custom
**Deposit ERC-20** is minted representing the locked `gem`. The `gem` never
leaves the adapter except to the `withdrawal` address or back to an
`InputConduit` for repayment.

The clearest surviving artifact of the Maker↔Centrifuge relationship after the
Tinlake-era `v1/tinlake-maker-lib` (MIP22).

## `lp-xcm-relayer`
0★ · Solidity · LGPL-3.0 · 2023-09-19

"Liquidity Pools Axelar XCM Relayer" — the hop that carried Axelar messages into
Centrifuge Chain over XCM. Tiny; the whole README is its title.

## `twamm`
3★ · Rust · LGPL-3.0 · 2023-03-31

Time-Weighted AMM for Substrate: submit/cancel/update long-term swaps over an
embedded AMM (`pallet-asset-conversion` by default). **Contains no source** — the
repo is a README, LICENSE and license templates. A design sketch, never built.

## `axelar-cgp-substrate`
2★ · Rust · GPL-3.0 · 2023-09-05

Axelar's Cross-chain Gateway Protocol as Substrate pallets: `gateway/`, `libs/`,
`sample-runtime/`, `integration-test/`. README reads, in full, "FILL UP!".

## `chain-custom-types`
0★ · Go · no license · 2024-04-10

Centrifuge Chain's custom SCALE types packaged for use with
`go-substrate-rpc-client`. Small and mechanical, but required to decode chain
state from Go.

## `substrate-pallet-multi-account`
10★ · Rust · LGPL-3.0 · 2020-08-26 — **self-declared DEPRECATED**

Multisig with a *static* `AccountId` and dynamic threshold/signatories. The
README points users to upstream Substrate `pallet-proxy` + `pallet-multisig`
instead. Historical only.

## `clp-wasm`
13★ · C++ → WebAssembly · 2021-02-07

COIN-OR **CLP** linear-programming solver compiled to WASM, with arithmetic
mapped to `boost::multiprecision` 100-decimal floats because standard doubles
lose precision above 2^53 — i.e. above ordinary 18-decimal token amounts.

This is the **epoch solver**: Tinlake/V2 pools closed epochs by solving a
constrained optimisation over investment and redemption orders subject to
tranche ratios and reserve limits. Live demo:
https://centrifuge.github.io/clp-wasm/

Genuinely reusable outside Centrifuge, and the only place the epoch-solving math
is legible.

## `centrifuge-chain-functional-test`
1★ · TypeScript · 2020-03-21 — early functional test client for the chain.
