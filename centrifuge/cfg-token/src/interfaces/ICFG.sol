// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {IDelegationToken} from "src/interfaces/IDelegationToken.sol";

interface ICFG is IDelegationToken {
    /// @notice Burns sender's tokens.
    function burn(uint256 value) external;
}
