// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

abstract contract LSTStorage is Initializable {
    address public standardBridge;

    modifier onlyBridge {
        require(msg.sender == standardBridge, "LSTStorage: only bridge is callable");
        _;
    }

    function __LSTStorage_init(address _standardBridge) internal onlyInitializing {
        standardBridge = _standardBridge;
    }

    function withdraw(bytes32 depositHash, uint256 amount) external virtual;
}
