// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.28;

import {Auth} from "protocol-v3/misc/Auth.sol";
import {IERC20, IERC20Metadata, IERC20Wrapper} from "protocol-v3/misc/interfaces/IERC20.sol";

interface IERC20Mutate is IERC20 {
    function mint(address account, uint256 amount) external;

    function burn(uint256 amount) external;
}

contract IouCfg is Auth, IERC20, IERC20Metadata, IERC20Wrapper {
    address public immutable escrow;
    address public immutable newCfg;
    address public immutable legacyCfg;
    /// @inheritdoc IERC20Metadata
    uint8 public immutable decimals;

    constructor(address initialWard, address escrow_, address newCfg_, address legacyCfg_) Auth(initialWard) {
        escrow = escrow_;
        newCfg = newCfg_;
        legacyCfg = legacyCfg_;
        decimals = IERC20Metadata(newCfg_).decimals();
    }

    // --- IERC20 Implementation ---
    /// @inheritdoc IERC20
    function totalSupply() external pure returns (uint256) {
        return 0;
    }

    /// @inheritdoc IERC20
    function balanceOf(address) external pure returns (uint256) {
        return 0;
    }

    /// @inheritdoc IERC20
    function transfer(address, uint256) external pure returns (bool) {
        revert("Unsupported");
    }

    /// @inheritdoc IERC20
    function allowance(address, address) external pure returns (uint256) {
        return 0;
    }

    /// @dev A transferFrom function that mints the new CFG tokens and burns the IOU tokens. Only AUTH can call this
    /// function.
    function transferFrom(address sender, address receiver, uint256 amount) external auth returns (bool) {
        // Ensures that only for the direction "Centrifuge to Eth", tokens are minted
        require(sender == escrow, "IouCfg/invalid-sender");

        // Mint wCfg to this contract in order to keep issuance in line and withdrawTo possible
        IERC20Mutate(legacyCfg).mint(address(this), amount);
        IERC20Mutate(newCfg).mint(receiver, amount);

        // IOU is settled and burned
        emit Transfer(sender, address(0), amount);

        return true;
    }

    /// @dev Actually needed in order for this contract to work with the pool manager
    function approve(address, uint256) public virtual returns (bool) {
        return true;
    }

    // --- IERC20Metadata Implementation ---
    /// @inheritdoc IERC20Metadata
    function name() external pure returns (string memory) {
        return "Centrifuge IOU CFG";
    }

    /// @inheritdoc IERC20Metadata
    function symbol() external pure returns (string memory) {
        return "iouCFG";
    }

    // ---- IERC20Wrapper Implementation ----
    /// @dev Compliant to `ERC20Wrapper` contract from OZ for convenience.
    function depositFor(address account, uint256 value) external returns (bool) {
        require(account != address(0), "IouCfg/zero-address");
        require(account != address(this), "IouCfg/self-address");

        IERC20(legacyCfg).transferFrom(msg.sender, address(this), value);
        IERC20Mutate(newCfg).mint(account, value);
        return true;
    }

    /// @dev Compliant to `ERC20Wrapper` contract from OZ for convenience.
    function withdrawTo(address account, uint256 value) external returns (bool) {
        require(account != address(0), "IouCfg/zero-address");
        require(account != address(this), "IouCfg/self-address");

        IERC20Mutate(newCfg).transferFrom(msg.sender, address(this), value);
        IERC20Mutate(newCfg).burn(value);
        IERC20(legacyCfg).transfer(account, value);
        return true;
    }

    /// @dev To ease wrapping via the bundler contract:
    function underlying() external view returns (address) {
        return legacyCfg;
    }
}
