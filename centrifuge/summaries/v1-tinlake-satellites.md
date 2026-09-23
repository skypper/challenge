# The Tinlake satellite repos (`v1/`)

Tinlake was built dapptools-style: many small, single-purpose repos wired
together at deploy time. Each is a few hundred KB. Collected here because
individually they say little, together they map the V1 system.

| Repo | ★ | What it is |
|---|---|---|
| [`tinlake-maker-lib`](../v1/tinlake-maker-lib) | 10 | **The Maker integration.** Implements [MIP22](https://forum.makerdao.com/t/mip22-centrifuge-direct-liquidation-module/3930) — the Centrifuge Direct Liquidation Module — on top of Maker's MIP21 RWA contracts. `adapter-contracts.png` and `Properties.md` (invariants) are the good bits. This is the machinery behind DAI being backed by real-world assets. |
| [`tinlake-subgraph`](../v1/tinlake-subgraph) | 11 | The Graph subgraph for Tinlake — `schema.graphql` is a compact data model of pools, loans, tranches and rewards. Also computes CFG reward accrual. Last touched 2024-02. |
| [`tinlake-apps`](../v1/tinlake-apps) | 0 | **The Tinlake frontend monorepo**: `tinlake-ui/`, `tinlake.js/` (JS client), `onboarding-ui/` + `onboarding-api/`, `tinlake-bot/`, `gateway/`, `e2e-tests/`. Supersedes the separately-archived `tinlake-ui` and `tinlake.js` repos. Still receiving commits in 2026 — legacy pools need a UI. |
| [`tinlake-auth`](../v1/tinlake-auth) | 2 | The `ward`/`rely`/`deny` pattern, lifted from MakerDAO `dss`. Ten lines that shaped every Centrifuge codebase since, `protocol/src/misc/Auth.sol` included. |
| [`tinlake-math`](../v1/tinlake-math) | 3 | Fixed-point + compounding-interest math, based on the Dai Savings Rate. |
| [`tinlake-erc20`](../v1/tinlake-erc20) | 2 | Minimal ERC-20, "copied from dai.sol". |
| [`tinlake-title`](../v1/tinlake-title) | 2 | Ownership/permission tracking via an NFT — the loan "title" and the proxy-auth mechanism. |
| [`tinlake-proxy`](../v1/tinlake-proxy) | 1 | `ds-proxy` extended so authentication is an **NFT ownership check** rather than an address. See `proxy_actions_graph.svg`. |
| [`tinlake-actions`](../v1/tinlake-actions) | 0 | The action contracts `tinlake-proxy` delegatecalls into — borrow/repay/invest as single user-facing operations. |
| [`tinlake-deploy`](../v1/tinlake-deploy) | 3 | Deployment scripts (mainnet + testnets), Dockerised. |
| [`tinlake-spells-mainnet`](../v1/tinlake-spells-mainnet) | 1 | MakerDAO-style **spells** — one-shot governance-executed contracts, one per pool change. `archive/` is a per-pool history of every parameter change ever made. `migration-contracts/` covers pool upgrades. |
| [`tinlake-pools-mainnet`](../v1/tinlake-pools-mainnet) | 3 | Pool **metadata registry**: `metadata/` + `profiles/` per pool, published to IPFS. The only public record of who the issuers actually were. |
| [`tinlake-nftfeed`](../v1/tinlake-nftfeed) | 0 | Early NFT price feed, superseded by `tinlake/src/borrower/feed/`. |
| [`tinlake-asset-nft`](../v1/tinlake-asset-nft) | 0 | The collateral NFT contract. |

**Not cloned** (dead or duplicative): `tinlake-ui` and `tinlake.js` (archived —
both live inside `tinlake-apps`), `tinlake-solver-ui`, `tinlake.info`,
`tinlake-registry`, `tinlake-claim-rad`, `tinlake-memberadmin`,
`tinlake-tranche-worker`, `tinlake-maker-tests`, `tinlake-maker-integration`,
`tinlake-rpc-tests`, `tinlake-proxy-actions`, `tinlake-pool-config`,
`tinlake-pools-cli`, `tinlake-pools-kovan`, `tinlake-pools-goerli`,
`tinlake-spells-kovan`, `e2e-tests`.
