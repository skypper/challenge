// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {PoolId} from "centrifuge/src/core/types/PoolId.sol";

import {CentrifugeIntegrationTestWithUtils} from "centrifuge/test/integration/Integration.t.sol";

contract IntegrationTest is CentrifugeIntegrationTestWithUtils {
    address public HUB_MANAGER = makeAddr("HubManager");

    PoolId poolId;

    function setUp() public override {
        super.setUp();

        poolId = hubRegistry.poolId(LOCAL_CENTRIFUGE_ID, 1);
        vm.prank(address(adminSafe));
        opsGuardian.createPool(poolId, HUB_MANAGER, USD_ID);

        // HUB_MANAGER now fully controls the pool
    }

    function testManagerIsSetup() public view {
        assertEq(hubRegistry.manager(poolId, HUB_MANAGER), true);
    }
}
