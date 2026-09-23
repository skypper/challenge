// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {D18} from "centrifuge/src/misc/types/D18.sol";
import {PoolId} from "centrifuge/src/core/types/PoolId.sol";
import {AssetId} from "centrifuge/src/core/types/AssetId.sol";
import {ShareClassId} from "centrifuge/src/core/types/ShareClassId.sol";

/// @title  IDepositRedeemFeeManager
/// @notice A wrapper around BatchRequestManager that applies deposit and redeem fees to share prices
interface IDepositRedeemFeeManager {
    //----------------------------------------------------------------------------------------------
    // Events
    //----------------------------------------------------------------------------------------------

    event FeesUpdated(PoolId indexed poolId, D18 depositFee, D18 redeemFee);

    event IssueSharesWithFee(
        PoolId indexed poolId,
        ShareClassId indexed scId,
        AssetId indexed depositAssetId,
        uint32 epochId,
        D18 originalPrice,
        D18 adjustedPrice,
        D18 depositFee
    );

    event RevokeSharesWithFee(
        PoolId indexed poolId,
        ShareClassId indexed scId,
        AssetId indexed payoutAssetId,
        uint32 epochId,
        D18 originalPrice,
        D18 adjustedPrice,
        D18 redeemFee
    );

    //----------------------------------------------------------------------------------------------
    // Errors
    //----------------------------------------------------------------------------------------------

    error NotHubManager();
    error FeeTooHigh();

    //----------------------------------------------------------------------------------------------
    // Administration
    //----------------------------------------------------------------------------------------------

    /// @notice Set the deposit and redeem fees for a pool
    /// @dev    Only callable by hub managers of the pool
    /// @param  poolId The pool identifier
    /// @param  newDepositFee The fee to deduct from share price on deposits (in D18 format, e.g., 0.01e18 = 1%)
    /// @param  newRedeemFee The fee to deduct from share price on redeems (in D18 format, e.g., 0.01e18 = 1%)
    function setFees(PoolId poolId, D18 newDepositFee, D18 newRedeemFee) external;

    //----------------------------------------------------------------------------------------------
    // Manager actions
    //----------------------------------------------------------------------------------------------

    /// @notice Issue shares with deposit fee applied to the price
    /// @dev    Wraps BatchRequestManager.issueShares with fee-adjusted price
    /// @param  poolId The pool identifier
    /// @param  scId The share class identifier
    /// @param  depositAssetId The asset identifier for deposits
    /// @param  nowIssueEpochId The current issue epoch identifier
    /// @param  pricePoolPerShare The price of pool currency per share unit (before fee)
    /// @param  extraGasLimit Additional gas limit for cross-chain operations
    /// @param  refund Address to receive unused gas refund
    function issueShares(
        PoolId poolId,
        ShareClassId scId,
        AssetId depositAssetId,
        uint32 nowIssueEpochId,
        D18 pricePoolPerShare,
        uint128 extraGasLimit,
        address refund
    ) external payable;

    /// @notice Revoke shares with redeem fee applied to the price
    /// @dev    Wraps BatchRequestManager.revokeShares with fee-adjusted price
    /// @param  poolId The pool identifier
    /// @param  scId The share class identifier
    /// @param  payoutAssetId The asset identifier for payouts
    /// @param  nowRevokeEpochId The current revoke epoch identifier
    /// @param  pricePoolPerShare The price of pool currency per share unit (before fee)
    /// @param  extraGasLimit Additional gas limit for cross-chain operations
    /// @param  refund Address to receive unused gas refund
    function revokeShares(
        PoolId poolId,
        ShareClassId scId,
        AssetId payoutAssetId,
        uint32 nowRevokeEpochId,
        D18 pricePoolPerShare,
        uint128 extraGasLimit,
        address refund
    ) external payable;

    //----------------------------------------------------------------------------------------------
    // View methods
    //----------------------------------------------------------------------------------------------

    /// @notice Get the deposit fee for a pool
    /// @param  poolId The pool identifier
    /// @return The deposit fee in D18 format
    function depositFee(PoolId poolId) external view returns (D18);

    /// @notice Get the redeem fee for a pool
    /// @param  poolId The pool identifier
    /// @return The redeem fee in D18 format
    function redeemFee(PoolId poolId) external view returns (D18);
}
