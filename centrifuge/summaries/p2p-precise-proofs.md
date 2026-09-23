# `centrifuge/precise-proofs`

| | |
|---|---|
| **URL** | https://github.com/centrifuge/precise-proofs |
| **Tier** | P2P era — but genuinely reusable |
| **Language** | Go · **License** MIT |
| **Stars** | ~63 · **Last commit** 2022-11-23 |
| **Local size** | ~872 KB |

## What it is

**Field-level Merkle proofs over protobuf messages.** Given an arbitrary protobuf
message, it flattens the object, orders fields deterministically by label, and
builds a Merkle tree in which each *field* is a leaf — so you can hand someone a
proof of one field's value that they can verify against a root hash, without
seeing anything else in the document.

The determinism is the whole trick: flattening + label ordering means two parties
independently computing the tree from the same message always agree, so the root
is a stable commitment to a structured document.

Independent of Centrifuge, this is a clean, well-scoped solution to "selective
disclosure over structured data", and the reason it has more stars than
`protocol`.

Intro: [Introducing Precise-Proofs](https://medium.com/centrifuge/introducing-precise-proofs-create-validate-field-level-merkle-proofs-a31af9220df0)

## Related

`p2p/centrifuge-protobufs` (the messages it proves over), `p2p/pod` (the
consumer), `p2p/precise-proofs-js` (a JS port, 2019, unmaintained).
