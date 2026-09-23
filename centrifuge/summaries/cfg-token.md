# `centrifuge/cfg-token`

| | |
|---|---|
| **URL** | https://github.com/centrifuge/cfg-token |
| **Tier** | Official — the governance token |
| **Language** | Solidity (Foundry) |
| **License** | dual: **GPL-2.0-or-later or BUSL 1.1**, your choice |
| **Stars** | 0 · **Last commit** 2025-04-03 |
| **Local size** | ~1.1 MB |

## What it is

The EVM CFG token — the implementation of **[CP149](../cps/cps/CP149/CP149.md)**,
which deprecated chain-native CFG *and* Wrapped CFG (WCFG) and consolidated both
into one ERC-20 on Ethereum at
`0xcccCCCcCCC33D538DBC2EE4fEab0a7A1FF4e8A94`.

```
src/CFG.sol               the token
src/DelegationToken.sol   onchain vote delegation
src/IouCfg.sol            the migration IOU
audits/2025-03-Spearbit.pdf
```

The delegation logic is **adapted from the Morpho token**
(`morpho-org/morpho-token`) — worth noting if you already know that codebase.

## Tokenomics (as of June 2026, per the docs)

Total supply 697,164,473 CFG (includes CP149's 115M: 15M unlocked May 2025, 100M
vesting linearly to April 2029). 3% annual inflation, all accruing to the
Treasury. 54.6% considered released. Team 12%, vesting to May 2030.

## Related

`cps/cps/CP149/`, `documentation/docs/getting-started/token-summary/`.
