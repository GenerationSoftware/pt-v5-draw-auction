// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Erc5164Account } from "erc5164-account/Erc5164Account.sol";
import { Erc5164AccountCallEncoder } from "erc5164-account/libraries/Erc5164AccountCallEncoder.sol";
import { MessageDispatcherArbitrum } from "erc5164/ethereum-arbitrum/EthereumToArbitrumDispatcher.sol";

import {
    RngAuctionRelayer,
    StartRngAuction,
    IRngAuctionRelayListener
} from "./abstract/RngAuctionRelayer.sol";

contract RngAuctionRelayerErc5164Account is RngAuctionRelayer {

    event RelayedToDispatcher(address indexed rewardRecipient, bytes32 indexed messageId);

    MessageDispatcherArbitrum public immutable messageDispatcher;
    Erc5164Account public immutable account;
    uint256 public immutable toChainId;

    constructor(
        StartRngAuction _startRngAuction,
        IRngAuctionRelayListener _rngRelayListener,
        MessageDispatcherArbitrum _messageDispatcher,
        Erc5164Account _account,
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
            Erc5164AccountCallEncoder.encodeCalldata(address(rngAuctionRelayListener), 0, listenerCalldata)
        );
        emit RelayedToDispatcher(rewardRecipient, messageId);

        return messageId;
    }
}
