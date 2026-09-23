# Centrifuge Starter Kit

This repository contains sample implementations of contracts for [Centrifuge](https://github.com/centrifuge/protocol).

## How to extend the protocol

The Centrifuge Protocol is built on an immutable core protocol architecture, with a modular design that enables customized products to be built on top of it.

Built on top of the immutable core, the protocol supports various extension points that enable customization without modifying core contracts, including:
* [Adapters](https://github.com/centrifuge/protocol/tree/main/src/adapters): Cross-chain messaging adapters
* [Hooks](https://github.com/centrifuge/protocol/tree/main/src/hooks): Transfer hook implementations for custom compliance requirements
* [Hub Managers](https://github.com/centrifuge/protocol/tree/main/src/managers/hub): Management contracts for NAV, order management, investor management, onchain accounting, and more
* [Balance Sheet Managers](https://github.com/centrifuge/protocol/tree/main/src/managers/spoke): ERC20/ERC6909 token management per spoke network
* [Valuations](https://github.com/centrifuge/protocol/tree/main/src/valuations): Pricing for ERC20/ERC6909 tokens in the protocol

More details about the modularity of the protocol can be found in the [documentation](https://docs.centrifuge.io/developer/protocol/features/modularity/).

## `DepositRedeemFeeManager` (Hub Manager)

A sample Hub Manager that wraps `BatchRequestManager.issueShares` and `BatchRequestManager.revokeShares` to apply configurable deposit and redeem fees.

### Features

- **Deposit fee**: Increases the effective share price, so investors receive fewer shares for their deposit
- **Redeem fee**: Decreases the effective share price, so investors receive less payout for their shares
- **Configurable**: Fees can be set per pool by authorized hub managers via `setFees()`

### Usage

```solidity
// Deploy the fee manager
DepositRedeemFeeManager feeManager = new DepositRedeemFeeManager(hubRegistry, batchRequestManager);

// Register as hub manager for your pool
hub.updateHubManager(poolId, address(feeManager), true);

// Set fees (1% deposit, 2% redeem)
feeManager.setFees(poolId, d18(0.01e18), d18(0.02e18));

// Use issueShares/revokeShares through the fee manager instead of batchRequestManager
feeManager.issueShares{value: gas}(poolId, scId, assetId, epochId, pricePoolPerShare, extraGas, refund);
feeManager.revokeShares{value: gas}(poolId, scId, assetId, epochId, pricePoolPerShare, extraGas, refund);
```

### Note

This contract only implements fee accounting by adjusting prices. Withdrawing the corresponding fee assets from the holdings should be implemented separately.

## License

MIT
