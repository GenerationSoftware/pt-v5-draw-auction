// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RemoteOwner } from "remote-owner/RemoteOwner.sol";
import { RemoteOwnerCallEncoder } from "remote-owner/libraries/RemoteOwnerCallEncoder.sol";
import { IMessageDispatcher } from "erc5164-interfaces/interfaces/IMessageDispatcher.sol";

import {
    RngAuctionRelayer,
    RngAuction,
    IRngAuctionRelayListener
} from "./abstract/RngAuctionRelayer.sol";

/// @notice Emitted when the message dispatcher is the zero address
error MessageDispatcherIsZeroAddress();

/// @notice Emitted when the remote owner is the zero address
error RemoteOwnerIsZeroAddress();

/// @notice Emitted when the relayer listener is the zero address
error RemoteRngAuctionRelayListenerIsZeroAddress();

/// @title RngAuctionRelayerRemoteOwner
/// @author G9 Software Inc.
/// @notice This contract allows anyone to relay RNG results to an IRngAuctionRelayListener on another chain.
/// @dev This contract uses a Remote Owner, which allows a contract on one chain to operate an address on another chain.
contract RngAuctionRelayerRemoteOwner is RngAuctionRelayer {

    /// @notice Emitted when the relay was successfully dispatched to the ERC-5164 Dispatcher
    /// @param messageDispatcher The ERC-5164 Dispatcher to use to bridge messages
    /// @param remoteOwnerChainId The chain ID that the Remote Owner is deployed to.
    /// @param remoteOwner The address of the Remote Owner on the other chain whom should call the remote relayer
    /// @param remoteRngAuctionRelayListener The address of the IRngAuctionRelayListener to relay to on the other chain.
    /// @param rewardRecipient The address that shall receive the RNG relay reward.
    /// @param messageId The message ID of the dispatched message.
    event RelayedToDispatcher(
        IMessageDispatcher messageDispatcher,
        uint256 indexed remoteOwnerChainId,
        RemoteOwner remoteOwner,
        IRngAuctionRelayListener remoteRngAuctionRelayListener,
        address indexed rewardRecipient,
        bytes32 indexed messageId
    );

    /// @notice Constructs a new contract
    /// @param _rngAuction The RNG auction to pull results from.
    constructor(
        RngAuction _rngAuction
    ) RngAuctionRelayer(_rngAuction) {}

    /// @notice Relays the RNG results through the 5164 message dispatcher to the remote rngAuctionRelayListener on the other chain.
    /// @dev Note that some bridges require an additional transaction to bridge the message.
    /// For example, both Arbitrum and zkSync require off-chain information to accomplish this. See ERC-5164 implementations for more details.
    /// @param _messageDispatcher The ERC-5164 Dispatcher to use to bridge messages
    /// @param _remoteOwnerChainId The chain ID that the Remote Owner is deployed to.
    /// @param _remoteOwner The address of the Remote Owner on the other chain whom should call the remote relayer
    /// @param _remoteRngAuctionRelayListener The address of the IRngAuctionRelayListener to relay to on the other chain.
    /// @param _rewardRecipient The address that shall receive the RngAuctionRelay reward. Note that this address must be able to receive rewards on the other chain.
    /// @return The message ID of the dispatched message.
    function relay(
        IMessageDispatcher _messageDispatcher,
        uint256 _remoteOwnerChainId,
        RemoteOwner _remoteOwner,
        IRngAuctionRelayListener _remoteRngAuctionRelayListener,
        address _rewardRecipient
    ) external returns (bytes32) {
        if (address(_messageDispatcher) == address(0)) {
            revert MessageDispatcherIsZeroAddress();
        }
        if (address(_remoteOwner) == address(0)) {
            revert RemoteOwnerIsZeroAddress();
        }
        if (address(_remoteRngAuctionRelayListener) == address(0)) {
            revert RemoteRngAuctionRelayListenerIsZeroAddress();
        }
        bytes memory listenerCalldata = _encodeCalldata(_rewardRecipient);
        bytes32 messageId = _messageDispatcher.dispatchMessage(
            _remoteOwnerChainId,
            address(_remoteOwner),
            RemoteOwnerCallEncoder.encodeCalldata(
                address(_remoteRngAuctionRelayListener), 0, listenerCalldata
            )
        );
        emit RelayedToDispatcher(
            _messageDispatcher,
            _remoteOwnerChainId,
            _remoteOwner,
            _remoteRngAuctionRelayListener,
            _rewardRecipient,
            messageId
        );
        return messageId;
    }
}
