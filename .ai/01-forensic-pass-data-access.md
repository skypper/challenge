# Forensic pass: how the data access layer was discovered

Everything here was read from Ethereum mainnet on 2026-09-22 with two tools: the Etherscan v2 API
(key in `.env`) and Foundry `cast` against `https://ethereum-rpc.publicnode.com`. No archive node.
Visual map: https://claude.ai/artifact/QgSs4G76hLxqmp5pwoWBAb

## 1. Method

Start from the one address you are given and walk outward. Never guess an address; every one
below came from either a view function on a contract you already had, or from Etherscan's
verified-contract name for an address that appeared in an event.

1. **Get the source.** Etherscan `getsourcecode` (Blockscout as keyless fallback). ACRDX is
   Centrifuge V3 `ShareToken`: an ERC-20 with a `hook`, `authTransferFrom`, and `uint128` balances.
   It holds shares only. No price, no cash.
2. **Bound the window.** Etherscan `getblocknobytime` for Aug 1 and Sep 1 2026 →
   blocks `25,656,292` → `25,878,704`.
3. **Pull every log on the token in the window.** Nine `Transfer` events. Two end at `0x0`
   (burns). The transfers before each burn name three contracts you do not know yet.
4. **Name unknown addresses.** Etherscan `getsourcecode` → `ContractName`. This turned
   `0x9fb6…` into `PoolEscrow`, `0xf482…` into `AsyncRequestManager`, `0x12a1…` into
   `BalanceSheet`, `0xd81e…` into `GnosisSafeProxy` (an investor).
5. **Follow view-function pointers.** `token.vault(USDC)` → AsyncVault. `vault.manager()` →
   AsyncRequestManager. `arm.spoke()`, `arm.balanceSheet()` → Spoke, BalanceSheet.
   `bs.escrow(poolId)` → PoolEscrow. `brm.hub()` → Hub. `hub.shareClassManager()`,
   `hub.holdings()`, `hub.hubRegistry()` → the hub-side ledger.
6. **Decode a settlement receipt.** `cast receipt <burn tx>` → 12 logs. Fetch the verified ABI
   of every emitting contract, `cast keccak` each event signature, decode topics/data. One receipt
   yields the price used, the payout, the shares burned, and the investor.
7. **Pull August logs from each contract, filtered on the share class id.** This gives the
   surrounding lifecycle: request → approve → revoke → claim.
8. **Find the third-party feed.** Web search → Chronicle. Its Ethereum address came from a public
   repo that already monitors this token; confirmed by Etherscan name
   `ChronicleVAO_Centrifuge_ACRDX_Consumer_7`.
9. **Decode the feed's history.** `Poked(address,uint128,uint48)` events, ~20-minute cadence,
   value changes once per business day.

Pitfalls hit on the way, so you do not repeat them:
- Etherscan `getLogs` needs 32-byte topics (pad `bytes16` scId with 32 trailing zeros) and returns
  a *string* in `result` on error. Always check `typeof result`.
- Rate limit at ~5 req/s on the free key. Sleep 300 ms between calls.
- `zsh` does not word-split unquoted variables and has aliases `g`, `rd`. Use unusual function names.
- The Chronicle contract has no `latestRoundData()`. Use `read()` / `readWithAge()` /
  `tryReadWithAge()`. Calls from `address(0)` are tolled (allowed).
- The Centrifuge repo at `../centrifuge` is v3.3-rc1; deployed ACRDX is v3.1. Use
  `sdk/src/abi/*.abi.ts` for deployed signatures, Solidity at HEAD for mechanics.

## 2. Identifiers

```
poolId        281474976710664            (= centrifugeId 1 << 48 | 8; hub chain is Ethereum)
scId          0x00010000000000080000000000000001
USDC          0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
USDC assetId  5192296858534827628530496329220097
```

## 3. Contracts (Ethereum mainnet)

| Role | Contract | Address | Reads / events we use |
|---|---|---|---|
| shares | ShareToken ACRDX | `0x9477724bb54ad5417de8baff29e59df3fb4da74f` | `totalSupply`, `hook`, `vault(asset)`, `Transfer`, `File`, `Rely`, `Deny`, `VaultUpdate`, `SetHookData` |
| price, reference (spoke) | Spoke | `0xEC3582fcDc34078a4B7a8c75a5a3AE46f48525aB` | `pricePoolPerShare(pool,sc,false)`, `markersPricePoolPerShare(pool,sc)` → (computedAt, maxAge, validUntil), `UpdateSharePrice` |
| price, reference (hub) | ShareClassManager | `0xaFFC269c8fe18EE9C7DDb22301AC2c2507d69BEf` | `pricePoolPerShare(pool,sc)`, `totalIssuance(pool,sc)`, `UpdatePricePoolPerShare` |
| price, execution | BatchRequestManager | `0xc52bd1bdfa0135147d3f01a0b6d6cd0a831dfe77` | `RevokeShares`, `IssueShares`, `ApproveRedeems`, `ClaimRedeem`, `UpdateRedeemRequest`; `epochId`, `epochRedeemAmounts`, `epochInvestAmounts`, `pendingRedeem`, `pendingDeposit` |
| price, third party | Chronicle ACRDX oracle | `0x9a3bF392f86acd1b1EC07d026B326302eAED7488` | `readWithAge()`, `tryReadWithAge()`, `Poked` |
| cash | PoolEscrow | `0x9fb6b4deb5413d17c9169329b00491a05f12218e` | `holding(sc, asset, 0)` → (total, reserved), `availableBalanceOf` |
| cash | USDC | (above) | `balanceOf(PoolEscrow)`, `Transfer` to/from escrow |
| cash / shares mover | BalanceSheet | `0x12a110ce5f0fc871cc72bc7ecaf35cf39dd0f43e` | `availableBalanceOf`, `queuedShares`, `queuedAssets`, `NoteDeposit`, `NoteWithdraw`, `Withdraw`, `Revoke`, `Issue`, `TransferSharesFrom` |
| investor entry | AsyncVault (USDC) | `0x74A739EA1Dc67c5a0179ebad665D1D3c4b80B712` | `pricePerShare`, `priceLastUpdated`, `pendingRedeemRequest(0,u)`, `pendingDepositRequest(0,u)`, `RedeemRequest`, `RedeemClaimable`, `Withdraw`, `CancelRedeem*` |
| per-investor state | AsyncRequestManager | `0xf48256abddf96ecddc4b3dbd23e8c1921f9761ae` | `investments(vault, user)` |
| issuer entry | Hub | `0xA4A7Bb3831958463b3FE3E27A6a160F764341953` | target of the price push (`multicall` → `updateSharePrice` + `notifySharePrice`) |
| hub cash ledger | Holdings | `0x3f0c8D8d2637881c3f6d8531F51a47c2094C918d` | `isInitialized`, `amount`, `value` (all zero for this pool) |
| whitelist | FullRestrictions | `0x423322445818be56F8A317ADEBA0bdB487B71608` | only that `token.hook()` still equals it |
| cash on/off ramp | OnOfframpManager | `0x2e7aaea62a9c2def12b2939e50911b39fc768ca5` | surfaces as BalanceSheet `NoteDeposit` / `Withdraw` |
| router | VaultRouter | `0xf684014771c01e50b8b526968b3a1e33acda63f6` | `sender` on investor requests |

Other chains: token + Spoke at the same addresses on Plume and Base; Optimism token is
`0x2fabf1c784b8583d63c00c5c9c0377d8cf1a3245`. Supply 2026-09-22: Ethereum 237,532.68,
Plume 20,299,759.93, Optimism 97,931.99, Base 0.

## 4. Actors

| Who | Address | Does |
|---|---|---|
| Issuer / manager key | `0x7bf090b97f896fb77e852cc98aa52a8cb7dc02ec` (EOA) | every price push to Hub; 8 of 11 ACRDX settlement txs in August |
| Chronicle pokers | `0x7ab54bec47947c788428988015f8b7a9ff19b641`, via Multicall3 `0xca11…ca11` | `poke` ~every 20 min |
| Investor A | `0xb3dacc732509ba6b7f25ad149e56ca44fe901ab9` | holds 197,993.65; redeemed 117,810.79 on Aug 10, cancelled the rest |
| Investor B | `0xd81e0983e8e133d34670728406d08637374e545d` (Safe) | redeemed 23,526.03 on Aug 14; 39,538.03 still pending |
| Small depositor | `0x354114f5e003efbe1b4b727cbfd4bb858f45d01e` | 1 share, 99 USDC pending deposit |

## 5. Event topics

```
Transfer(address,address,uint256)                         0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef
UpdateSharePrice(uint64,bytes16,uint128,uint64)           0x50ae94913f401513d2eded2f37844a070743c57ff5148fcfaf081085653a2856
Poked(address,uint128,uint48)                             0x9f8b8154174dc4a9ed8bbe5a985ecf6d8b2db481a1c64a02c8d94ae7929e0ba6
```
All others: fetch the verified ABI and `cast keccak` the signature at startup. Do not hardcode.

## 6. The three pipes (who posts the price where)

- **A, reference.** Issuer key → `Hub.multicall(updateSharePrice, notifySharePrice)` → in the same
  tx ShareClassManager and Spoke store `(price, computedAt)`. `computedAt` is always 12:00 UTC of
  the NAV date. Normal lag T+1 weekdays, T+3 over weekends. Remote spokes get it via Gateway.
- **B, execution.** Same issuer key → `BatchRequestManager.approveRedeems(…)` then
  `revokeShares(…, pricePoolPerShare, …)`. Price is a plain argument. Not compared to A on-chain.
  Callback → AsyncRequestManager → BalanceSheet burns shares and earmarks USDC in escrow.
- **C, third party.** Chronicle validators → `poke` → oracle. Independent of A and B. Read by
  Morpho, Grove, and by us.

## 7. Historical reads without an archive node

| Need | Source |
|---|---|
| Spoke price at block X | last `UpdateSharePrice` ≤ X |
| Chronicle value at block X | last `Poked` ≤ X |
| Execution price at block X | `RevokeShares` / `IssueShares` at X |
| Escrow USDC at block X | sum of USDC `Transfer` to/from escrow ≤ X (reconstructable) |
| Escrow `holding.total/reserved` at block X | **archive only** |
| `pendingRedeemRequest` at block X | reconstruct from `UpdateRedeemRequest` events, or archive |

## 8. Reproduce the key numbers

```
source .env; export ETH_RPC_URL=https://ethereum-rpc.publicnode.com
SPOKE=0xEC3582fcDc34078a4B7a8c75a5a3AE46f48525aB; BRM=0xc52bd1bdfa0135147d3f01a0b6d6cd0a831dfe77
POOL=281474976710664; SC=0x00010000000000080000000000000001; AID=5192296858534827628530496329220097
cast call $SPOKE 'pricePoolPerShare(uint64,bytes16,bool)(uint128)' $POOL $SC false
cast call $SPOKE 'markersPricePoolPerShare(uint64,bytes16)(uint64,uint64,uint64)' $POOL $SC
cast call 0x9a3bF392f86acd1b1EC07d026B326302eAED7488 'readWithAge()(uint256,uint256)'
cast call $BRM 'epochRedeemAmounts(uint64,bytes16,uint128,uint32)(uint128,uint128,uint128,uint128,uint128,uint64)' $POOL $SC $AID 4
cast receipt 0x281b4438e045bfc6cae5346a2006c821f2f43034b1166aad8903c46600f3fd4f --json | jq '.logs|length'
```
