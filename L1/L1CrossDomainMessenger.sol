// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { Predeploys } from "src/libraries/Predeploys.sol";
import { OptimismPortal } from "src/L1/OptimismPortal.sol";
import { CrossDomainMessenger } from "src/universal/CrossDomainMessenger.sol";
import { ISemver } from "src/universal/ISemver.sol";
import { SuperchainConfig } from "src/L1/SuperchainConfig.sol";

/// @custom:proxied
/// @title L1CrossDomainMessenger
/// @notice The L1CrossDomainMessenger is a message passing interface between L1 and L2 responsible
///         for sending and receiving data on the L1 side. Users are encouraged to use this
///         interface instead of interacting with lower-level contracts directly.
contract L1CrossDomainMessenger is CrossDomainMessenger, ISemver {
    /// @notice Contract of the SuperchainConfig.
    SuperchainConfig public superchainConfig;

    /// @notice Contract of the OptimismPortal.
    /// @custom:network-specific
    OptimismPortal public portal;

    /// @notice Semantic version.
    /// @custom:semver 2.3.0
    string public constant version = "2.3.0";

    /// @param sender Address of the sender of the message.
    /// @param value  LST value mint in ETH along with the message from tokens exchange to the recipient.
    event SentMessageExtensionLST(address indexed sender, uint256 value);

    /// @notice Constructs the L1CrossDomainMessenger contract.
    constructor() CrossDomainMessenger() {
        initialize({ _superchainConfig: SuperchainConfig(address(0)), _portal: OptimismPortal(payable(address(0))) });
    }

    /// @notice Initializes the contract.
    /// @param _superchainConfig Contract of the SuperchainConfig contract on this network.
    /// @param _portal Contract of the OptimismPortal contract on this network.
    function initialize(SuperchainConfig _superchainConfig, OptimismPortal _portal) public initializer {
        superchainConfig = _superchainConfig;
        portal = _portal;
        __CrossDomainMessenger_init({ _otherMessenger: CrossDomainMessenger(Predeploys.L2_CROSS_DOMAIN_MESSENGER) });
    }

    /// @notice Getter function for the OptimismPortal contract on this chain.
    ///         Public getter is legacy and will be removed in the future. Use `portal()` instead.
    /// @return Contract of the OptimismPortal on this chain.
    /// @custom:legacy
    function PORTAL() external view returns (OptimismPortal) {
        return portal;
    }

    /// @inheritdoc CrossDomainMessenger
    function _sendMessage(address _to, uint64 _gasLimit, uint256 _value, bytes memory _data) internal override {
        portal.depositTransaction{ value: _value }({
            _to: _to,
            _value: _value,
            _gasLimit: _gasLimit,
            _isCreation: false,
            _data: _data
        });
    }

    /// @notice Sends a message to some target address on the other chain. Note that if the call
    ///         always reverts, then the message will be unrelayable, and any ETH sent will be
    ///         permanently locked. The same will occur if the target on the other chain is
    ///         considered unsafe (see the _isUnsafeTarget() function).
    /// @param _target      Target contract or wallet address.
    /// @param _value       LST value
    /// @param _message     Message to trigger the target address with.
    /// @param _minGasLimit Minimum gas limit that the message can be executed with.
    function sendLstMessage(address _target, uint256 _value, bytes calldata _message, uint32 _minGasLimit) external {
        // reverts when caller is not the standard bridge.
        require(msg.sender == portal.systemConfig().l1StandardBridge(), "OptimismPortal: only the standard bridge is callable");

        // Triggers a message to the other messenger. Note that the amount of gas provided to the
        // message is the amount of gas requested by the user PLUS the base gas value. We want to
        // guarantee the property that the call to the target contract will always have at least
        // the minimum gas limit specified by the user.
        portal.depositLstTransaction({
            _to: address(otherMessenger),
            _gasLimit: baseGas(_message, _minGasLimit),
            _value: _value,
            _data: abi.encodeWithSelector(
                this.relayMessage.selector, messageNonce(), msg.sender, _target, _value, _minGasLimit, _message
                )
        });

        emit SentMessage(_target, msg.sender, _message, messageNonce(), _minGasLimit);
        emit SentMessageExtensionLST(msg.sender, _value);

        unchecked {
            ++msgNonce;
        }
    }

    /// @inheritdoc CrossDomainMessenger
    function _isOtherMessenger() internal view override returns (bool) {
        return msg.sender == address(portal) && portal.l2Sender() == address(otherMessenger);
    }

    /// @inheritdoc CrossDomainMessenger
    function _isUnsafeTarget(address _target) internal view override returns (bool) {
        return _target == address(this) || _target == address(portal);
    }

    /// @inheritdoc CrossDomainMessenger
    function paused() public view override returns (bool) {
        return superchainConfig.paused();
    }
}
