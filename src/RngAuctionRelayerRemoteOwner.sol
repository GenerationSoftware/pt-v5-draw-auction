// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RemoteOwner } from "remote-owner/RemoteOwner.sol";
import { RemoteOwnerCallEncoder } from "remote-owner/libraries/RemoteOwnerCallEncoder.sol";
import { MessageDispatcherArbitrum } from "erc5164/ethereum-arbitrum/EthereumToArbitrumDispatcher.sol";

import {
    RngAuctionRelayer,
    StartRngAuction,
    IRngAuctionRelayListener
} from "./abstract/RngAuctionRelayer.sol";

contract RngAuctionRelayerRemoteOwner is RngAuctionRelayer {

    event RelayedToDispatcher(address indexed rewardRecipient, bytes32 indexed messageId);

    MessageDispatcherArbitrum public immutable messageDispatcher;
    RemoteOwner public immutable account;
    uint256 public immutable toChainId;

    constructor(
        StartRngAuction _startRngAuction,
        IRngAuctionRelayListener _rngRelayListener,
        MessageDispatcherArbitrum _messageDispatcher,
        RemoteOwner _account,
        uint256 _toChainId
    ) RngAuctionRelayer(_startRngAuction, _rngRelayListener) {
        messageDispatcher = _messageDispatcher;
        account = _account;
        toChainId = _toChainId;
    }

    function relay(
        address rewardRecipient
    ) external returns (bytes32) {
        bytes memory listenerCalldata = encodeCalldata(rewardRecipient);
        bytes32 messageId = messageDispatcher.dispatchMessage(
            toChainId,
            address(account),
            RemoteOwnerCallEncoder.encodeCalldata(address(rngAuctionRelayListener), 0, listenerCalldata)
        );
        emit RelayedToDispatcher(rewardRecipient, messageId);

        return messageId;
    }
}
