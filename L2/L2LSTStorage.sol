// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { Predeploys } from "src/libraries/Predeploys.sol";
import { StandardBridge } from "src/universal/StandardBridge.sol";
import { LSTStorage } from "src/universal/LSTStorage.sol";
import { ISemver } from "src/universal/ISemver.sol";

contract L2LSTStorage is LSTStorage, ISemver {
    mapping(bytes32 => Deposit) public deposits;

    struct Deposit {
        uint number;
        address token;
        address holder;
        uint256 locked;
        uint256 price;
    }

    /// @notice Semantic version.
    /// @custom:semver 1.0.0
    string public constant version = "1.0.0";

    constructor() LSTStorage()  {
        initialize();
    }

    function initialize() public initializer {
        __LSTStorage_init({  _standardBridge: Predeploys.L2_LST_STORAGE });
    }

    function getDeposit(bytes32 depositHash) external returns (Deposit memory) {
        return deposits[depositHash];
    }

    function deposit(bytes32 depositHash, address token, address holder, uint256 amount, uint256 value) external onlyBridge {
        deposits[depositHash] = Deposit({
            number: block.number,
            token: token,
            holder: holder,
            locked: amount,
            price: (value * 1 ether) / amount
        });
    }

    function withdraw(bytes32 depositHash, uint256 amount) external override onlyBridge {
        Deposit storage deposit = deposits[depositHash];
        require(amount <= deposit.locked, "L2LSTStorage: amount must not exceeds current locked");
        deposit.locked -= amount;
    }
}
