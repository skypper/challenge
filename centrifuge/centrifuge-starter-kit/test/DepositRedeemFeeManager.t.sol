// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {D18, d18} from "centrifuge/src/misc/types/D18.sol";
import {CastLib} from "centrifuge/src/misc/libraries/CastLib.sol";

import {MAX_MESSAGE_COST as GAS} from "centrifuge/src/core/messaging/interfaces/IGasService.sol";
import {IHubRequestManager} from "centrifuge/src/core/hub/interfaces/IHubRequestManager.sol";
import {VaultUpdateKind} from "centrifuge/src/core/messaging/libraries/MessageLib.sol";

import {IAsyncVault} from "centrifuge/src/vaults/interfaces/IAsyncVault.sol";
import {IAsyncRedeemVault} from "centrifuge/src/vaults/interfaces/IAsyncVault.sol";

import {CentrifugeIntegrationTestWithUtils} from "centrifuge/test/integration/Integration.t.sol";

import {DepositRedeemFeeManager} from "../src/DepositRedeemFeeManager.sol";
import {IDepositRedeemFeeManager} from "../src/IDepositRedeemFeeManager.sol";

contract DepositRedeemFeeManagerTest is CentrifugeIntegrationTestWithUtils {
    using CastLib for *;

    DepositRedeemFeeManager public feeManager;

    address public INVESTOR = makeAddr("investor");
    address public REFUND = makeAddr("refund");

    uint128 constant DEPOSIT_AMOUNT = 1000e6; // 1000 USDC
    uint128 constant EXTRA_GAS = 100_000;

    D18 pricePoolPerShare = d18(1e18); // 1:1
    D18 pricePoolPerAsset = d18(1e18); // 1:1

    function setUp() public override {
        super.setUp();

        // Fund accounts first
        vm.deal(FM, 10 ether);
        vm.deal(INVESTOR, 1 ether);

        // Deploy fee manager
        feeManager = new DepositRedeemFeeManager(hubRegistry, batchRequestManager);

        // Create pool with FM as manager
        _createPool();
        _registerUSDC();

        // Add fee manager as a hub manager for the pool
        vm.prank(FM);
        hub.updateHubManager(POOL_A, address(feeManager), true);

        // Setup the pool configuration
        _configurePool();

        // Fund investor with USDC
        _mintUSDC(INVESTOR, DEPOSIT_AMOUNT);
    }

    function _configurePool() internal {
        vm.startPrank(FM);

        // Notify pool and share class to spoke (using freezeOnlyHook - no whitelisting required)
        hub.notifyPool{value: GAS}(POOL_A, LOCAL_CENTRIFUGE_ID, REFUND);
        hub.notifyShareClass{value: GAS}(
            POOL_A, SC_1, LOCAL_CENTRIFUGE_ID, address(freezeOnlyHook).toBytes32(), REFUND
        );

        // Set request manager
        hub.setRequestManager{value: GAS}(
            POOL_A,
            LOCAL_CENTRIFUGE_ID,
            IHubRequestManager(batchRequestManager),
            address(asyncRequestManager).toBytes32(),
            REFUND
        );

        // Update balance sheet manager
        hub.updateBalanceSheetManager{value: GAS}(
            POOL_A, LOCAL_CENTRIFUGE_ID, address(asyncRequestManager).toBytes32(), true, REFUND
        );

        // Deploy and link vault
        hub.updateVault{value: GAS}(
            POOL_A,
            SC_1,
            usdcId,
            address(asyncVaultFactory).toBytes32(),
            VaultUpdateKind.DeployAndLink,
            EXTRA_GAS,
            REFUND
        );

        // Set prices
        hub.updateSharePrice(POOL_A, SC_1, pricePoolPerShare, uint64(block.timestamp));
        hub.notifySharePrice{value: GAS}(POOL_A, SC_1, LOCAL_CENTRIFUGE_ID, REFUND);
        hub.notifyAssetPrice{value: GAS}(POOL_A, SC_1, usdcId, REFUND);

        vm.stopPrank();
    }

    //----------------------------------------------------------------------------------------------
    // setFees tests
    //----------------------------------------------------------------------------------------------

    function testSetFees() public {
        D18 depositFee = d18(0.01e18); // 1%
        D18 redeemFee = d18(0.02e18); // 2%

        vm.expectEmit(true, true, true, true);
        emit IDepositRedeemFeeManager.FeesUpdated(POOL_A, depositFee, redeemFee);

        vm.prank(FM);
        feeManager.setFees(POOL_A, depositFee, redeemFee);

        assertEq(feeManager.depositFee(POOL_A).raw(), depositFee.raw());
        assertEq(feeManager.redeemFee(POOL_A).raw(), redeemFee.raw());
    }

    function testSetFeesNotHubManager() public {
        address notManager = makeAddr("notManager");

        vm.prank(notManager);
        vm.expectRevert(IDepositRedeemFeeManager.NotHubManager.selector);
        feeManager.setFees(POOL_A, d18(0.01e18), d18(0.01e18));
    }

    function testSetFeesDepositFeeTooHigh() public {
        vm.prank(FM);
        vm.expectRevert(IDepositRedeemFeeManager.FeeTooHigh.selector);
        feeManager.setFees(POOL_A, d18(1e18), d18(0.01e18)); // 100% deposit fee
    }

    function testSetFeesRedeemFeeTooHigh() public {
        vm.prank(FM);
        vm.expectRevert(IDepositRedeemFeeManager.FeeTooHigh.selector);
        feeManager.setFees(POOL_A, d18(0.01e18), d18(1e18)); // 100% redeem fee
    }

    //----------------------------------------------------------------------------------------------
    // issueShares tests
    //----------------------------------------------------------------------------------------------

    function testIssueSharesWithZeroFee() public {
        // Setup: investor deposits
        _investorDeposit();

        // Approve deposits
        _approveDeposits();

        // Issue shares with zero fee (default)
        uint32 issueEpochId = batchRequestManager.nowIssueEpoch(POOL_A, SC_1, usdcId);

        vm.prank(FM);
        feeManager.issueShares{value: GAS}(POOL_A, SC_1, usdcId, issueEpochId, pricePoolPerShare, EXTRA_GAS, REFUND);

        // Verify shares were issued at original price
        _claimShares();
        assertApproxEqRel(
            spoke.shareToken(POOL_A, SC_1).balanceOf(INVESTOR), uint256(DEPOSIT_AMOUNT) * 1e12, 0.001e18, "shares mismatch"
        );
    }

    function testIssueSharesWithDepositFee() public {
        // Set 10% deposit fee
        D18 depositFee = d18(0.1e18);
        vm.prank(FM);
        feeManager.setFees(POOL_A, depositFee, d18(0));

        // Setup: investor deposits
        _investorDeposit();

        // Approve deposits
        _approveDeposits();

        // Issue shares with fee
        uint32 issueEpochId = batchRequestManager.nowIssueEpoch(POOL_A, SC_1, usdcId);

        vm.prank(FM);
        feeManager.issueShares{value: GAS}(POOL_A, SC_1, usdcId, issueEpochId, pricePoolPerShare, EXTRA_GAS, REFUND);

        // With 10% fee, price becomes 1 / 0.9 = 1.111...
        // So investor gets 1000 / 1.111... = 900 shares (approximately)
        _claimShares();
        uint256 expectedShares = 900e18; // 90% of deposit due to fee
        assertApproxEqRel(
            spoke.shareToken(POOL_A, SC_1).balanceOf(INVESTOR), expectedShares, 0.001e18, "shares mismatch"
        );
    }

    function testIssueSharesNotHubManager() public {
        address notManager = makeAddr("notManager");
        vm.deal(notManager, 1 ether);

        vm.prank(notManager);
        vm.expectRevert(IDepositRedeemFeeManager.NotHubManager.selector);
        feeManager.issueShares{value: GAS}(POOL_A, SC_1, usdcId, 1, pricePoolPerShare, EXTRA_GAS, REFUND);
    }

    //----------------------------------------------------------------------------------------------
    // revokeShares tests
    //----------------------------------------------------------------------------------------------

    function testRevokeSharesWithZeroFee() public {
        // First do a deposit to get shares
        _investorDeposit();
        _approveDeposits();
        uint32 issueEpochId = batchRequestManager.nowIssueEpoch(POOL_A, SC_1, usdcId);
        vm.prank(FM);
        feeManager.issueShares{value: GAS}(POOL_A, SC_1, usdcId, issueEpochId, pricePoolPerShare, EXTRA_GAS, REFUND);
        _claimShares();

        // Now redeem
        _investorRedeem();
        _approveRedeems();

        // Revoke shares with zero fee
        uint32 revokeEpochId = batchRequestManager.nowRevokeEpoch(POOL_A, SC_1, usdcId);

        vm.prank(FM);
        feeManager.revokeShares{value: GAS}(POOL_A, SC_1, usdcId, revokeEpochId, pricePoolPerShare, EXTRA_GAS, REFUND);

        // Verify payout at original price
        _claimPayout();
        assertApproxEqRel(usdc.balanceOf(INVESTOR), DEPOSIT_AMOUNT, 0.001e18, "payout mismatch");
    }

    function testRevokeSharesWithRedeemFee() public {
        // First do a deposit to get shares
        _investorDeposit();
        _approveDeposits();
        uint32 issueEpochId = batchRequestManager.nowIssueEpoch(POOL_A, SC_1, usdcId);
        vm.prank(FM);
        feeManager.issueShares{value: GAS}(POOL_A, SC_1, usdcId, issueEpochId, pricePoolPerShare, EXTRA_GAS, REFUND);
        _claimShares();

        // Set 10% redeem fee
        D18 redeemFee = d18(0.1e18);
        vm.prank(FM);
        feeManager.setFees(POOL_A, d18(0), redeemFee);

        // Now redeem
        _investorRedeem();
        _approveRedeems();

        // Revoke shares with fee
        uint32 revokeEpochId = batchRequestManager.nowRevokeEpoch(POOL_A, SC_1, usdcId);

        vm.prank(FM);
        feeManager.revokeShares{value: GAS}(POOL_A, SC_1, usdcId, revokeEpochId, pricePoolPerShare, EXTRA_GAS, REFUND);

        // With 10% fee, price becomes 1 * 0.9 = 0.9
        // So investor gets 1000 * 0.9 = 900 USDC
        _claimPayout();
        uint128 expectedPayout = 900e6; // 90% of shares value due to fee
        assertApproxEqRel(usdc.balanceOf(INVESTOR), expectedPayout, 0.001e18, "payout mismatch");
    }

    function testRevokeSharesNotHubManager() public {
        address notManager = makeAddr("notManager");
        vm.deal(notManager, 1 ether);

        vm.prank(notManager);
        vm.expectRevert(IDepositRedeemFeeManager.NotHubManager.selector);
        feeManager.revokeShares{value: GAS}(POOL_A, SC_1, usdcId, 1, pricePoolPerShare, EXTRA_GAS, REFUND);
    }

    //----------------------------------------------------------------------------------------------
    // Helper functions
    //----------------------------------------------------------------------------------------------

    function _investorDeposit() internal {
        IAsyncVault vault = IAsyncVault(address(vaultRegistry.vault(POOL_A, SC_1, usdcId, asyncRequestManager)));

        vm.startPrank(INVESTOR);
        usdc.approve(address(vault), DEPOSIT_AMOUNT);
        vault.requestDeposit(DEPOSIT_AMOUNT, INVESTOR, INVESTOR);
        vm.stopPrank();
    }

    function _approveDeposits() internal {
        uint32 depositEpochId = batchRequestManager.nowDepositEpoch(POOL_A, SC_1, usdcId);

        vm.prank(FM);
        batchRequestManager.approveDeposits{value: GAS}(
            POOL_A, SC_1, usdcId, depositEpochId, DEPOSIT_AMOUNT, pricePoolPerAsset, REFUND
        );
    }

    function _claimShares() internal {
        vm.prank(address(0)); // Anyone can call
        batchRequestManager.notifyDeposit{value: GAS}(
            POOL_A,
            SC_1,
            usdcId,
            INVESTOR.toBytes32(),
            batchRequestManager.maxDepositClaims(POOL_A, SC_1, INVESTOR.toBytes32(), usdcId),
            REFUND
        );

        IAsyncVault vault = IAsyncVault(address(vaultRegistry.vault(POOL_A, SC_1, usdcId, asyncRequestManager)));
        vm.startPrank(INVESTOR);
        vault.mint(vault.maxMint(INVESTOR), INVESTOR);
        vm.stopPrank();
    }

    function _investorRedeem() internal {
        IAsyncRedeemVault vault =
            IAsyncRedeemVault(address(vaultRegistry.vault(POOL_A, SC_1, usdcId, asyncRequestManager)));
        uint256 shares = spoke.shareToken(POOL_A, SC_1).balanceOf(INVESTOR);

        vm.prank(INVESTOR);
        vault.requestRedeem(shares, INVESTOR, INVESTOR);
    }

    function _approveRedeems() internal {
        uint32 redeemEpochId = batchRequestManager.nowRedeemEpoch(POOL_A, SC_1, usdcId);

        // Get pending shares from pendingRedeem
        uint128 shares = batchRequestManager.pendingRedeem(POOL_A, SC_1, usdcId);

        vm.prank(FM);
        batchRequestManager.approveRedeems(POOL_A, SC_1, usdcId, redeemEpochId, shares, pricePoolPerAsset);
    }

    function _claimPayout() internal {
        vm.prank(address(0)); // Anyone can call
        batchRequestManager.notifyRedeem{value: GAS}(
            POOL_A,
            SC_1,
            usdcId,
            INVESTOR.toBytes32(),
            batchRequestManager.maxRedeemClaims(POOL_A, SC_1, INVESTOR.toBytes32(), usdcId),
            REFUND
        );

        IAsyncRedeemVault vault =
            IAsyncRedeemVault(address(vaultRegistry.vault(POOL_A, SC_1, usdcId, asyncRequestManager)));
        vm.startPrank(INVESTOR);
        vault.withdraw(vault.maxWithdraw(INVESTOR), INVESTOR, INVESTOR);
        vm.stopPrank();
    }
}
