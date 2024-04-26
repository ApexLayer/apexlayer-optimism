// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {StandardBridge} from 'src/universal/StandardBridge.sol';
import {LSTStorage} from 'src/universal/LSTStorage.sol';
import {ISemver} from 'src/universal/ISemver.sol';

contract L1LSTStorage is LSTStorage, ISemver, OwnableUpgradeable {
    mapping(address => mapping(address => bytes32[])) public depositsHash;
    mapping(bytes32 => uint256) public deposits;

    mapping(address => bool) public whitelisted;

    event WhitelistToken(address token);
    event BlacklistToken(address token);

    /// @notice Semantic version.
    /// @custom:semver 1.0.0
    string public constant version = '1.0.0';

    constructor() LSTStorage() {
        initialize({_owner: address(0xdEaD), _standardBridge: address(0)});
    }

    function initialize(address _owner, address _standardBridge) public initializer {
        super.__Ownable_init();
        super._transferOwnership(_owner);
        __LSTStorage_init({_standardBridge: _standardBridge});
    }

    function whitelist(address token) public onlyOwner {
        whitelisted[token] = true;
        emit WhitelistToken(token);
    }

    function blacklist(address token) public onlyOwner {
        whitelisted[token] = false;
        emit BlacklistToken(token);
    }

    function depositsCount(address token, address holder) external view returns (uint) {
        return depositsHash[token][holder].length;
    }

    function deposit(
        address token,
        address from,
        address to,
        uint256 amount,
        uint256 value
    ) external onlyBridge returns (bytes32) {
        require(amount > 0, 'L1LSTStorage: amount must be greater than zero');
        require(value > 0, 'L1LSTStorage: value must be greater than zero');

        bytes32 depositHash = keccak256(abi.encodePacked(block.number, token, from, to, amount, value));
        depositsHash[token][to].push(depositHash);
        deposits[depositHash] = amount;

        return depositHash;
    }

    function withdraw(bytes32 depositHash, uint256 amount) external override onlyBridge {
        require(amount <= deposits[depositHash], 'L1LSTStorage: amount must not exceeds current locked');
        deposits[depositHash] -= amount;
    }
}
