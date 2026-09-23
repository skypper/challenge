# `centrifuge/pod` — the Private Off-chain Data node

| | |
|---|---|
| **URL** | https://github.com/centrifuge/pod |
| **Tier** | P2P era — historical |
| **Language** | Go (libp2p) · **License** MIT |
| **Stars** | ~80 · **Last commit** 2024-04-10 |
| **Local size** | ~12 MB |

## What it is

Centrifuge's **original** protocol, before Tinlake was the product: a
peer-to-peer network for exchanging business documents (invoices, purchase
orders) privately between counterparties, while anchoring only cryptographic
commitments onchain.

The model, in short:

1. Two businesses hold a shared document off-chain. Each field is a leaf in a
   Merkle tree (`p2p/precise-proofs`).
2. Only the **root hash** is anchored on Centrifuge Chain (`pallets/anchors`).
3. Either party can then prove *individual fields* to a third party without
   revealing the rest of the document.
4. That proof backs a **user-mintable, privacy-enabled NFT**
   (`p2p/privacy-enabled-erc721`) — mint an "unpaid invoice" NFT whose
   authenticity anyone can verify against the anchored root.
5. That NFT is the collateral you lock in Tinlake.

So the P2P layer is not a dead end — it is where Tinlake's collateral came from.
Tinlake later accepted plain NFTs and off-chain legal agreements instead, and
this whole layer fell away.

## Contents

Go node with libp2p networking, an identity system (CentrifugeID with separate
P2P encryption keys and document signing keys), a document service bus that
external systems subscribe to, a JSON API, and jobs/queue infrastructure.
Audited by **Trail of Bits** (`security/audits/node/`).

## Related

`p2p/precise-proofs`, `p2p/centrifuge-protobufs` (the document schemas),
`p2p/privacy-enabled-erc721`, `v2/centrifuge-chain` (`pallets/anchors`,
`pallets/keystore`), `documentation/docs/developer/legacy/pod/`.
