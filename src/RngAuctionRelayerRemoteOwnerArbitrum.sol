// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { PrizePool } from "pt-v5-prize-pool/PrizePool.sol";
import { IMessageDispatcher } from "erc5164-interfaces/interfaces/IMessageDispatcher.sol";
import { RemoteOwner } from "remote-owner/RemoteOwner.sol";
import { RemoteOwnerCallEncoder } from "remote-owner/libraries/RemoteOwnerCallEncoder.sol";
import {
  IMessageDispatcherArbitrum
} from "erc5164-interfaces/interfaces/extensions/IMessageDispatcherArbitrum.sol";

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

/// @notice Emitted when the `gasLimit` passed to the `relay` function is lower than or equal to 1.
error GasLimitIsLTEOne();

/// @notice Emitted when the `gasPriceBid` passed to the `relay` function is lower than or equal to 1.
error GasPriceBidIsLTEOne();

struct ArbitrumRelayParams {
  address refundAddress;
  uint256 gasLimit;
  uint256 maxSubmissionCost;
  uint256 gasPriceBid;
}

/**
 * @title RngAuctionRelayerRemoteOwnerArbitrum
 * @author G9 Software Inc.
 * @notice This contract allows anyone to relay RNG results to an IRngAuctionRelayListener on the Arbitrum chain.
 * @dev This contract uses a Remote Owner, which allows a contract on one chain to operate an address on the Arbitrum chain.
 */
contract RngAuctionRelayerRemoteOwnerArbitrum is RngAuctionRelayer {
  /**
   * @notice Emitted when the relay was successfully dispatched to the ERC-5164 Dispatcher
   * @param messageDispatcher The ERC-5164 Dispatcher to use to bridge messages
   * @param remoteOwnerChainId The chain ID that the Remote Owner is deployed to.
   * @param remoteOwner The address of the Remote Owner on the other chain whom should call the remote relayer
   * @param remoteRngAuctionRelayListener The address of the IRngAuctionRelayListener to relay to on the other chain.
   * @param remotePrizePool The address of the PrizePool on the other chain.
   * @param rewardRecipient The address that shall receive the RNG relay reward.
   * @param messageId The message ID of the dispatched message.
   */
  event RelayedToDispatcher(
    IMessageDispatcherArbitrum messageDispatcher,
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
   * @notice Relays the RNG results through the 5164 message dispatcher to the remote rngAuctionRelayListener on the Arbitrum chain.
   * @dev `_gasLimit` and `_gasPriceBid` should not be set to 1 as that is used to trigger the Arbitrum RetryableData error.
   * @dev `_refundAddress` is also passed as `callValueRefundAddress` and can cancel the Arbitrum retryable ticket.
   * @dev The payable amount is passed onto the message dispatcher to use as the L2 gas fee. Any gas refund will be given to the `_refundAddress` on L2.
   * @param _messageDispatcher The ERC-5164 Dispatcher to use to bridge messages
   * @param _remoteOwnerChainId The chain ID that the Remote Owner is deployed to
   * @param _remoteOwner The address of the Remote Owner on the Arbitrum chain whom should call the remote relayer
   * @param _remoteRngAuctionRelayListener The address of the IRngAuctionRelayListener to relay to on the Arbitrum chain
   * @param _remotePrizePool The address of the PrizePool on the Arbitrum chain
   * @param _rewardRecipient The address that shall receive the RngAuctionRelay reward. Note that this address must be able to receive rewards on the Arbitrum chain.
   * @param _arbitrumRelayParams Struct containing Arbitrum relay parameters. Including:
   * - refundAddress Address that will receive the `excessFeeRefund` amount if any
   * - gasLimit Gas limit at which the message will be executed on the Arbitrum chain
   * - maxSubmissionCost Max gas deducted from user's Arbitrum balance to cover base submission fee
   * - gasPriceBid Gas price bid for Arbitrum execution
   * @return The message ID of the dispatched message
   */
  function relay(
    IMessageDispatcherArbitrum _messageDispatcher,
    uint256 _remoteOwnerChainId,
    RemoteOwner _remoteOwner,
    IRngAuctionRelayListener _remoteRngAuctionRelayListener,
    PrizePool _remotePrizePool,
    address _rewardRecipient,
    ArbitrumRelayParams calldata _arbitrumRelayParams
  ) external payable returns (bytes32) {
    if (address(_messageDispatcher) == address(0)) {
      revert MessageDispatcherIsZeroAddress();
    }

    if (address(_remoteOwner) == address(0)) {
      revert RemoteOwnerIsZeroAddress();
    }

    if (address(_remoteRngAuctionRelayListener) == address(0)) {
      revert RemoteRngAuctionRelayListenerIsZeroAddress();
    }

    if (_arbitrumRelayParams.gasLimit <= 1) {
      revert GasLimitIsLTEOne();
    }

    if (_arbitrumRelayParams.gasPriceBid <= 1) {
      revert GasPriceBidIsLTEOne();
    }

    (bytes32 _messageId, ) = _messageDispatcher.dispatchAndProcessMessage{ value: msg.value }(
      _remoteOwnerChainId,
      address(_remoteOwner),
      RemoteOwnerCallEncoder.encodeCalldata(
        address(_remoteRngAuctionRelayListener),
        0,
        _encodeCalldata(_remotePrizePool, _rewardRecipient)
      ),
      _arbitrumRelayParams.refundAddress,
      _arbitrumRelayParams.gasLimit,
      _arbitrumRelayParams.maxSubmissionCost,
      _arbitrumRelayParams.gasPriceBid
    );

    emit RelayedToDispatcher(
      _messageDispatcher,
      _remoteOwnerChainId,
      _remoteOwner,
      _remoteRngAuctionRelayListener,
      _remotePrizePool,
      _rewardRecipient,
      _messageId
    );

    return _messageId;
  }
}
