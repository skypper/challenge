# `centrifuge/liquidity-pools` — Centrifuge V1/V2 on EVM

| | |
|---|---|
| **URL** | https://github.com/centrifuge/liquidity-pools |
| **Tier** | V2 — direct predecessor of `protocol` |
| **Language** | Solidity (Foundry) · **License** LGPL-3.0 |
| **Stars** | ~28 · **Last commit** 2025-01-13 (*Add escrow migration spell*) |
| **Local size** | ~2.8 MB |

## What it is

The EVM half of Centrifuge V2: contracts deployed on any EVM chain that let
investors deposit into pools whose *state lived on Centrifuge Chain*. Note the
version labels in the audit tables — what the docs call protocol **V1.0 and
V2.0/V2.1** is this repo; V3.0 onwards is `protocol`.

Its most lasting contribution is upstream: **Centrifuge co-authored ERC-7540**
(async tokenized vaults), and `ERC7540Vault.sol` here is the reference-grade
first implementation.

## Contracts

```
ERC7540Vault.sol          async deposit/redeem vault (ERC-4626 extension)
InvestmentManager.sol     pool creation, tranche deployment, investment logic
PoolManager.sol           asset bookkeeping, tranche-token transfers
Escrow.sol                single global escrow  ← V3 replaced this with per-pool
CentrifugeRouter.sol      user-facing multicall entry point
Root.sol / Auth.sol       ward-based access (MakerDAO `dss` lineage)
admin/Guardian.sol        one guardian  ← V3 splits into Protocol + Ops
gateway/Gateway.sol       Multi-Message Aggregation: full payload to 1 adapter,
                          proofs to n-1
gateway/adapters/axelar/  Adapter.sol, Forwarder.sol
gateway/GasService.sol
token/Tranche.sol         the tranche token (ERC-20)
token/RestrictionManager.sol   transfer restrictions
factories/                ERC7540VaultFactory, TrancheFactory, TransferProxyFactory
libraries/                Bytes, Cast, Math, Messages, EIP712, Transient, ...
```

## Read it as a diff against V3

Almost every V3 design decision is a reaction to something here. The mapping is
close enough to be useful:

| V2 (`liquidity-pools`) | V3 (`protocol`) |
|---|---|
| `PoolManager` + `InvestmentManager` | `Spoke` / `SpokeRegistry` + `Hub` / request managers |
| single `Escrow` | `PoolEscrow` per pool, per share class, with reservations |
| tranche token | share token + `ShareTokenRegistrar` |
| `RestrictionManager` | pluggable `token/hooks/*` |
| one `Guardian` | `ProtocolGuardian` + `OpsGuardian`, 48h timelock |
| MMA: payload + n-1 proofs | `MultiAdapter` quorum with numbered sessions |
| Axelar only | LayerZero, Axelar, Chainlink CCIP, Hyperlane, Standby |
| state on Centrifuge Chain | hub chain is any EVM chain of the pool's choosing |
| epoch settlement mandatory | `IHubRequestManager` is pluggable; sync deposits skip it |

## Audits

`security/audits/liquidity-pools/` (Code4rena 2023-09, SRLabs, Spearbit ×2), and
the same reports are re-listed in the docs' audit table under V1.0/V2.0/V2.1.
The full Code4rena contest snapshot is in `../audits/2023-09-centrifuge/`.

## Related

`../audits/2023-09-centrifuge*`, `v2/centrifuge-chain` (`pallets/liquidity-pools*`),
`v2/lp-xcm-relayer`, `protocol` (successor).
