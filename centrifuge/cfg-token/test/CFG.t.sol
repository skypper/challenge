// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {CFG} from "src/CFG.sol";
import {IDelegationToken, Delegation, Signature} from "src/interfaces/IDelegationToken.sol";
import {IAuth} from "protocol-v3/misc/interfaces/IAuth.sol";
import "forge-std/Test.sol";

contract CFGTest is Test {
    CFG token = new CFG(address(this));

    function testDeployment() public view {
        assertEq(token.name(), "Centrifuge");
        assertEq(token.symbol(), "CFG");
        assertEq(token.decimals(), 18);
    }

    function testMint(address nonWard, address destination, uint256 mintAmount) public {
        vm.assume(nonWard != address(this));
        vm.assume(destination != address(this) && destination.code.length == 0 && destination != address(0));

        assertEq(token.wards(address(this)), 1);
        assertEq(token.wards(nonWard), 0);

        vm.prank(nonWard);
        vm.expectRevert(IAuth.NotAuthorized.selector);
        token.mint(destination, mintAmount);

        assertEq(token.balanceOf(destination), 0);

        vm.prank(address(this));
        token.mint(destination, mintAmount);

        assertEq(token.balanceOf(destination), mintAmount);
    }

    function testBurnAuth(address nonWard, uint256 mintAmount, uint256 burnAmount) public {
        vm.assume(nonWard != address(this));
        burnAmount = bound(burnAmount, 0, mintAmount);

        assertEq(token.wards(address(this)), 1);
        assertEq(token.wards(nonWard), 0);

        token.mint(address(this), mintAmount);
        assertEq(token.balanceOf(address(this)), mintAmount);

        vm.prank(nonWard);
        vm.expectRevert(IAuth.NotAuthorized.selector);
        token.burn(address(this), burnAmount);

        token.burn(address(this), burnAmount);
        assertEq(token.balanceOf(address(this)), mintAmount - burnAmount);
    }

    function testBurnSelf(address user, uint256 mintAmount, uint256 burnAmount) public {
        vm.assume(user != address(this) && user != address(0) && user != address(token));
        burnAmount = bound(burnAmount, 0, mintAmount);

        assertEq(token.wards(user), 0);

        token.mint(user, mintAmount);
        assertEq(token.balanceOf(user), mintAmount);

        vm.prank(user);
        token.burn(burnAmount);

        assertEq(token.balanceOf(user), mintAmount - burnAmount);
    }

    function testDelegateVotingPower(
        uint256 mintAmount,
        uint256 transferAmount,
        uint256 transferFromAmount,
        uint256 burnAmount,
        uint256 burnPermissionlessAmount,
        address delegatee,
        address user2,
        address delegatee2
    ) public {
        vm.assume(delegatee != address(this) && delegatee != address(0));
        vm.assume(user2 != delegatee && user2.code.length == 0 && user2 != address(this) && user2 != address(0));
        vm.assume(
            delegatee2 != delegatee && delegatee2 != user2 && delegatee2 != address(this) && delegatee2 != address(0)
        );
        transferAmount = bound(transferAmount, 0, mintAmount);
        transferFromAmount = bound(transferFromAmount, 0, mintAmount - transferAmount);
        burnAmount = bound(burnAmount, 0, mintAmount - transferAmount - transferFromAmount);
        burnPermissionlessAmount = bound(burnPermissionlessAmount, 0, transferAmount + transferFromAmount);

        token.mint(address(this), mintAmount);
        assertEq(token.balanceOf(address(this)), mintAmount);

        assertEq(token.delegatee(address(this)), address(0));
        assertEq(token.delegatee(user2), address(0));
        assertEq(token.delegatedVotingPower(delegatee), 0);
        assertEq(token.delegatedVotingPower(delegatee2), 0);

        token.delegate(delegatee);
        vm.prank(user2);
        token.delegate(delegatee2);

        assertEq(token.delegatee(address(this)), delegatee);
        assertEq(token.delegatee(user2), delegatee2);
        assertEq(token.delegatedVotingPower(delegatee), mintAmount);
        assertEq(token.delegatedVotingPower(delegatee2), 0);

        token.transfer(user2, transferAmount);

        assertEq(token.delegatee(address(this)), delegatee);
        assertEq(token.delegatee(user2), delegatee2);
        assertEq(token.delegatedVotingPower(delegatee), mintAmount - transferAmount);
        assertEq(token.delegatedVotingPower(delegatee2), transferAmount);

        token.transferFrom(address(this), user2, transferFromAmount);

        assertEq(token.delegatee(address(this)), delegatee);
        assertEq(token.delegatee(user2), delegatee2);
        assertEq(token.delegatedVotingPower(delegatee), mintAmount - transferAmount - transferFromAmount);
        assertEq(token.delegatedVotingPower(delegatee2), transferAmount + transferFromAmount);

        token.burn(address(this), burnAmount);

        assertEq(token.delegatee(address(this)), delegatee);
        assertEq(token.delegatee(user2), delegatee2);
        assertEq(token.delegatedVotingPower(delegatee), mintAmount - transferAmount - transferFromAmount - burnAmount);
        assertEq(token.delegatedVotingPower(delegatee2), transferAmount + transferFromAmount);

        vm.prank(user2);
        token.burn(burnPermissionlessAmount);

        assertEq(token.delegatee(address(this)), delegatee);
        assertEq(token.delegatee(user2), delegatee2);
        assertEq(token.delegatedVotingPower(delegatee), mintAmount - transferAmount - transferFromAmount - burnAmount);
        assertEq(token.delegatedVotingPower(delegatee2), transferAmount + transferFromAmount - burnPermissionlessAmount);
    }

    function testDelegateWithSig(address delegatee) public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);
        vm.assume(delegatee != owner && delegatee != address(0));

        uint256 nonce = token.delegationNonce(owner);
        Delegation memory delegation = Delegation(delegatee, nonce, block.timestamp);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01", token.DOMAIN_SEPARATOR(), keccak256(abi.encode(token.DELEGATION_TYPEHASH(), delegation))
                )
            )
        );

        assertEq(token.delegatee(owner), address(0));
        token.delegateWithSig(delegation, Signature(v, r, s));
        assertEq(token.delegatee(owner), delegatee);

        // Cannot re-use nonce
        delegation = Delegation(delegatee, nonce, block.timestamp);

        (v, r, s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01", token.DOMAIN_SEPARATOR(), keccak256(abi.encode(token.DELEGATION_TYPEHASH(), delegation))
                )
            )
        );

        vm.expectRevert(IDelegationToken.InvalidDelegationNonce.selector);
        token.delegateWithSig(delegation, Signature(v, r, s));

        // Cannot use expired permits
        delegation = Delegation(delegatee, token.delegationNonce(owner), block.timestamp - 1);

        (v, r, s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01", token.DOMAIN_SEPARATOR(), keccak256(abi.encode(token.DELEGATION_TYPEHASH(), delegation))
                )
            )
        );

        vm.expectRevert(IDelegationToken.DelegatesExpiredSignature.selector);
        token.delegateWithSig(delegation, Signature(v, r, s));

        // Cannot use invalid signature
        delegation = Delegation(delegatee, token.delegationNonce(owner), block.timestamp);

        (v, r, s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x02", token.DOMAIN_SEPARATOR(), keccak256(abi.encode(token.DELEGATION_TYPEHASH(), delegation))
                )
            )
        );

        vm.expectRevert(IDelegationToken.InvalidSignature.selector);
        token.delegateWithSig(delegation, Signature(v, bytes32(""), bytes32("")));
    }
}
