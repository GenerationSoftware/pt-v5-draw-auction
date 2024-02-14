// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { PrizePool } from "pt-v5-prize-pool/PrizePool.sol";
import { RemoteOwner } from "remote-owner/RemoteOwner.sol";
import { RemoteOwnerCallEncoder } from "remote-owner/libraries/RemoteOwnerCallEncoder.sol";
import {
  IMessageDispatcherOptimism
} from "erc5164-interfaces/interfaces/extensions/IMessageDispatcherOptimism.sol";

import {
  RngAuctionRelayer,
  RngAuction,
  IRngAuctionRelayListener
} from "./abstract/RngAuctionRelayer.sol";

/// @notice Emitted when the message dispatcher is the zero address.
error MessageDispatcherIsZeroAddress();

/// @notice Emitted when the remote owner is the zero address.
error RemoteOwnerIsZeroAddress();

/// @notice Emitted when the relayer listener is the zero address.
error RemoteRngAuctionRelayListenerIsZeroAddress();

/// @notice Emitted when the `gasLimit` passed to the `relay` function is zero.
error GasLimitIsZero();

/**
 * @title RngAuctionRelayerRemoteOwnerOptimism
 * @author G9 Software Inc.
 * @notice This contract allows anyone to relay RNG results to an IRngAuctionRelayListener on another chain.
 * @dev This contract uses a Remote Owner, which allows a contract on one chain to operate an address on another chain.
 */
contract RngAuctionRelayerRemoteOwnerOptimism is RngAuctionRelayer {
  /**
   * @notice Emitted when the relay was successfully dispatched to the ERC-5164 Dispatcher.
   * @param messageDispatcher The ERC-5164 Dispatcher to use to bridge messages
   * @param remoteOwnerChainId The chain ID that the Remote Owner is deployed to
   * @param remoteOwner The address of the Remote Owner on the Optimism chain whom should call the remote relayer
   * @param remoteRngAuctionRelayListener The address of the IRngAuctionRelayListener to relay to on the Optimism chain.
   * @param rewardRecipient The address that shall receive the RNG relay reward
   * @param messageId The message ID of the dispatched message
   */
  event RelayedToDispatcher(
    IMessageDispatcherOptimism messageDispatcher,
    uint256 indexed remoteOwnerChainId,
    RemoteOwner remoteOwner,
    IRngAuctionRelayListener remoteRngAuctionRelayListener,
    PrizePool remotePrizePool,
    address indexed rewardRecipient,
    bytes32 indexed messageId
  );

  /**
   * @notice Constructs a new contract
   * @param _rngAuction The RNG auction to pull results from.
   */
  constructor(RngAuction _rngAuction) RngAuctionRelayer(_rngAuction) {}

  /**
   * @notice Relays the RNG results through the 5164 message dispatcher to the remote rngAuctionRelayListener on the Optimism chain.
   * @param _messageDispatcher The ERC-5164 Dispatcher to use to bridge messages
   * @param _remoteOwnerChainId The chain ID that the Remote Owner is deployed to
   * @param _remoteOwner The address of the Remote Owner on the Optimism chain whom should call the remote relayer
   * @param _remoteRngAuctionRelayListener The address of the IRngAuctionRelayListener to relay to on the Optimism chain
   * @param _rewardRecipient The address that shall receive the RngAuctionRelay reward. Note that this address must be able to receive rewards on the Optimism chain.
   * @param _gasLimit Gas limit at which the message will be executed on the Optimism chain
   * @return The message ID of the dispatched message
   */
  function relay(
    IMessageDispatcherOptimism _messageDispatcher,
    uint256 _remoteOwnerChainId,
    RemoteOwner _remoteOwner,
    IRngAuctionRelayListener _remoteRngAuctionRelayListener,
    PrizePool _remotePrizePool,
    address _rewardRecipient,
    uint32 _gasLimit
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

    if (_gasLimit == 0) {
      revert GasLimitIsZero();
    }

    bytes memory listenerCalldata = _encodeCalldata(_remotePrizePool, _rewardRecipient);
    bytes32 messageId = _messageDispatcher.dispatchMessageWithGasLimit(
      _remoteOwnerChainId,
      address(_remoteOwner),
      RemoteOwnerCallEncoder.encodeCalldata(
        address(_remoteRngAuctionRelayListener),
        0,
        listenerCalldata
      ),
      _gasLimit
    );

    emit RelayedToDispatcher(
      _messageDispatcher,
      _remoteOwnerChainId,
      _remoteOwner,
      _remoteRngAuctionRelayListener,
      _remotePrizePool,
      _rewardRecipient,
      messageId
    );

    return messageId;
  }
}
