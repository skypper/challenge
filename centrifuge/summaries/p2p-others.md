# The P2P / document-protocol era (`p2p/`)

Centrifuge 2018–2022, before Tinlake became the product. Everything here is
historical, but it explains where Tinlake's collateral NFTs came from.

## `privacy-enabled-erc721` — 37★ · Solidity · AGPL-3.0 · 2020

Reference implementation of **user-mintable, privacy-enabled NFTs**. A user mints
an NFT themselves by supplying precise-proofs against an onchain **anchor
registry**; the contract verifies the fields it cares about against the anchored
document root without ever seeing the document. The mechanism the whole P2P stack
was built to enable.

[Write-up](https://medium.com/centrifuge/user-mintable-privacy-enabled-nft-via-ethereum-erc-721-662ba7e4425)

## `zk-nft-demo-contract` — 35★ · Solidity · AGPL-3.0 · 2019

Same idea, with **zkSNARKs** (ZoKrates) instead of Merkle proofs, hiding the
field values as well as the document. Explicitly a proof-of-concept prototype —
never productionised. Interesting as an early (2019) applied-ZK artifact.

## `centrifuge-ethereum-contracts` — 10★ · JS/Solidity · MIT · 2020

The Ethereum-side contracts of the original protocol, before the move to
Substrate: **anchor registry**, **identity registry**, NFT registries. Carries a
"very early alpha, not audited" disclaimer. The direct ancestor of
`pallets/anchors` in `v2/centrifuge-chain`.

## `centrifuge-protobufs` — 1★ · Go · MIT · 2022

Protobuf schemas + Go bindings for Centrifuge Documents — the wire format nodes
exchange. `coredocument/`, `documenttypes/`, `entity/`, `generic/`, `invoice`,
`purchaseorder`. The README's rules (never reuse field numbers; never prefix with
`XXX_`) exist because `precise-proofs` derives leaf ordering from the schema, so
a schema edit silently changes every historical root.

## `invoice-unpaid-nft` — 0★ · Solidity · AGPL-3.0 · 2019

The concrete NFT: "this invoice is unpaid". The literal object a Tinlake borrower
locked as collateral.

## `precise-proofs-js` — 1★ · JS · 2019

JS port of the proof verifier. Unmaintained.

## Papers

- **`protocol-paper`** — 3★ · TeX · CC-BY-SA-4.0 · 2019. The Centrifuge Protocol
  paper, chapter per file: document fields, version history, root hashes, state
  commit, protobufs+proofs, participants. Still the best explanation of the
  document model.
- **`paper-privacy-enabled-nfts`** — 8★ · TeX · 2018. *Privacy-Enabled NFTs:
  Self-Mintable Non-Fungible Tokens With Private Off-Chain Data.* Published
  2018-08-08 — early enough to be a real contribution to NFT design.
