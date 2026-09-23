// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IDepositRedeemFeeManager} from "./IDepositRedeemFeeManager.sol";

import {D18, d18} from "centrifuge/src/misc/types/D18.sol";
import {MathLib} from "centrifuge/src/misc/libraries/MathLib.sol";

import {PoolId} from "centrifuge/src/core/types/PoolId.sol";
import {AssetId} from "centrifuge/src/core/types/AssetId.sol";
import {ShareClassId} from "centrifuge/src/core/types/ShareClassId.sol";
import {IHubRegistry} from "centrifuge/src/core/hub/interfaces/IHubRegistry.sol";
import {IBatchRequestManager} from "centrifuge/src/vaults/interfaces/IBatchRequestManager.sol";

/// @title  DepositRedeemFeeManager
/// @notice A wrapper around BatchRequestManager that applies deposit and redeem fees to share prices.
///         This is a sample implementation of a Hub Manager that demonstrates how to extend
///         the Centrifuge protocol with custom fee logic.
/// @dev    The deposit fee increases the effective share price (investors get fewer shares),
///         while the redeem fee decreases the effective share price (investors get less payout).
///         This contract only implements fee accounting by adjusting prices. Withdrawing the
///         corresponding fee assets from the holdings should be implemented separately.
contract DepositRedeemFeeManager is IDepositRedeemFeeManager {
    using MathLib for uint128;

    D18 public constant MAX_FEE = D18.wrap(1e18);

    IHubRegistry public immutable hubRegistry;
    IBatchRequestManager public immutable batchRequestManager;

    mapping(PoolId => D18) public depositFee;
    mapping(PoolId => D18) public redeemFee;

    constructor(IHubRegistry hubRegistry_, IBatchRequestManager batchRequestManager_) {
        hubRegistry = hubRegistry_;
        batchRequestManager = batchRequestManager_;
    }

    modifier onlyHubManager(PoolId poolId) {
        require(hubRegistry.manager(poolId, msg.sender), NotHubManager());
        _;
    }

    //----------------------------------------------------------------------------------------------
    // Administration
    //----------------------------------------------------------------------------------------------

    /// @inheritdoc IDepositRedeemFeeManager
    function setFees(PoolId poolId, D18 newDepositFee, D18 newRedeemFee) external onlyHubManager(poolId) {
        require(newDepositFee.raw() < MAX_FEE.raw(), FeeTooHigh());
        require(newRedeemFee.raw() < MAX_FEE.raw(), FeeTooHigh());

        depositFee[poolId] = newDepositFee;
        redeemFee[poolId] = newRedeemFee;

        emit FeesUpdated(poolId, newDepositFee, newRedeemFee);
    }

    //----------------------------------------------------------------------------------------------
    // Manager actions
    //----------------------------------------------------------------------------------------------

    /// @inheritdoc IDepositRedeemFeeManager
    function issueShares(
        PoolId poolId,
        ShareClassId scId,
        AssetId depositAssetId,
        uint32 nowIssueEpochId,
        D18 pricePoolPerShare,
        uint128 extraGasLimit,
        address refund
    ) external payable onlyHubManager(poolId) {
        D18 fee = depositFee[poolId];
        // Increase price so investors get fewer shares: adjustedPrice = price / (1 - fee)
        D18 adjustedPrice = fee.isZero() ? pricePoolPerShare : pricePoolPerShare / (d18(1e18) - fee);

        batchRequestManager.issueShares{value: msg.value}(
            poolId, scId, depositAssetId, nowIssueEpochId, adjustedPrice, extraGasLimit, refund
        );

        emit IssueSharesWithFee(poolId, scId, depositAssetId, nowIssueEpochId, pricePoolPerShare, adjustedPrice, fee);
    }

    /// @inheritdoc IDepositRedeemFeeManager
    function revokeShares(
        PoolId poolId,
        ShareClassId scId,
        AssetId payoutAssetId,
        uint32 nowRevokeEpochId,
        D18 pricePoolPerShare,
        uint128 extraGasLimit,
        address refund
    ) external payable onlyHubManager(poolId) {
        D18 fee = redeemFee[poolId];
        // Decrease price so investors get less payout: adjustedPrice = price * (1 - fee)
        D18 adjustedPrice = fee.isZero() ? pricePoolPerShare : pricePoolPerShare * (d18(1e18) - fee);

        batchRequestManager.revokeShares{value: msg.value}(
            poolId, scId, payoutAssetId, nowRevokeEpochId, adjustedPrice, extraGasLimit, refund
        );

        emit RevokeSharesWithFee(poolId, scId, payoutAssetId, nowRevokeEpochId, pricePoolPerShare, adjustedPrice, fee);
    }
}
