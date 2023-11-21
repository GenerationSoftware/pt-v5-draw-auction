// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import { UD2x18 } from "prb-math/UD2x18.sol";
import { MessageLib } from "erc5164-interfaces/libraries/MessageLib.sol";

import { RngAuction } from "../src/RngAuction.sol";
import { IRngAuctionRelayListener } from "../src/interfaces/IRngAuctionRelayListener.sol";
import { AuctionResult } from "../src/interfaces/IAuction.sol";

import { RngRelayerBaseTest } from "./helpers/RngRelayerBaseTest.sol";

import {
  RngNotCompleted,
  RewardRecipientIsZeroAddress
} from "../src/abstract/RngAuctionRelayer.sol";

import {
  RngAuctionRelayerRemoteOwnerOptimism,
  IMessageDispatcherOptimism,
  RemoteOwner,
  MessageDispatcherIsZeroAddress,
  RemoteOwnerIsZeroAddress,
  RemoteRngAuctionRelayListenerIsZeroAddress,
  GasLimitIsZero,
  RemoteOwnerCallEncoder
} from "../src/RngAuctionRelayerRemoteOwnerOptimism.sol";

contract RngAuctionRelayerRemoteOwnerOptimismTest is RngRelayerBaseTest {
  event RelayedToDispatcher(
    IMessageDispatcherOptimism messageDispatcher,
    uint256 indexed remoteOwnerChainId,
    RemoteOwner remoteOwner,
    IRngAuctionRelayListener remoteRngAuctionRelayListener,
    address indexed rewardRecipient,
    bytes32 indexed messageId
  );

  RngAuctionRelayerRemoteOwnerOptimism relayer;

  IMessageDispatcherOptimism messageDispatcher;
  RemoteOwner remoteOwner;
  uint256 remoteOwnerChainId = 1;
  uint32 gasLimit = 250_000;

  function setUp() public override {
    super.setUp();
    messageDispatcher = IMessageDispatcherOptimism(makeAddr("messageDispatcher"));
    remoteOwner = RemoteOwner(payable(makeAddr("remoteOwner")));

    relayer = new RngAuctionRelayerRemoteOwnerOptimism(rngAuction);
  }

  function testConstructor() public {
    assertEq(address(relayer.rngAuction()), address(rngAuction));
  }

  function testRelay_happyPath() public {
    mockIsRngComplete(true);
    mockRngResults(123, 456);
    mockAuctionResult(address(this), UD2x18.wrap(0.5 ether));
    mockCurrentSequenceId(789);

    bytes memory data = RemoteOwnerCallEncoder.encodeCalldata(
      address(rngAuctionRelayListener),
      0,
      abi.encodeWithSelector(
        rngAuctionRelayListener.rngComplete.selector,
        123,
        456,
        address(this),
        789,
        AuctionResult(address(this), UD2x18.wrap(0.5 ether))
      )
    );

    address from = address(this);
    address to = address(remoteOwner);
    bytes32 messageId = MessageLib.computeMessageId(1, from, to, data);

    vm.mockCall(
      address(messageDispatcher),
      abi.encodeWithSelector(
        IMessageDispatcherOptimism.dispatchMessageWithGasLimit.selector,
        remoteOwnerChainId,
        to,
        data,
        gasLimit
      ),
      abi.encodePacked(messageId)
    );

    vm.expectEmit(true, true, false, false);

    emit RelayedToDispatcher(
      messageDispatcher,
      remoteOwnerChainId,
      remoteOwner,
      rngAuctionRelayListener,
      address(this),
      messageId
    );

    assertEq(
      relayer.relay(
        messageDispatcher,
        remoteOwnerChainId,
        remoteOwner,
        rngAuctionRelayListener,
        address(this),
        gasLimit
      ),
      messageId
    );
  }

  function testRelay_MessageDispatcherIsZeroAddress() public {
    vm.expectRevert(abi.encodeWithSelector(MessageDispatcherIsZeroAddress.selector));
    relayer.relay(
      IMessageDispatcherOptimism(address(0)),
      remoteOwnerChainId,
      remoteOwner,
      rngAuctionRelayListener,
      address(this),
      gasLimit
    );
  }

  function testRelay_RemoteOwnerIsZeroAddress() public {
    vm.expectRevert(abi.encodeWithSelector(RemoteOwnerIsZeroAddress.selector));
    relayer.relay(
      messageDispatcher,
      remoteOwnerChainId,
      RemoteOwner(payable(0)),
      rngAuctionRelayListener,
      address(this),
      gasLimit
    );
  }

  function testRelay_RemoteRngAuctionRelayListenerIsZeroAddress() public {
    vm.expectRevert(abi.encodeWithSelector(RemoteRngAuctionRelayListenerIsZeroAddress.selector));
    relayer.relay(
      messageDispatcher,
      remoteOwnerChainId,
      remoteOwner,
      IRngAuctionRelayListener(address(0)),
      address(this),
      gasLimit
    );
  }

  function testRelay_RewardRecipientIsZeroAddress() public {
    vm.expectRevert(abi.encodeWithSelector(RewardRecipientIsZeroAddress.selector));
    relayer.relay(
      messageDispatcher,
      remoteOwnerChainId,
      remoteOwner,
      rngAuctionRelayListener,
      address(0),
      gasLimit
    );
  }

  function testRelay_GasLimitIsZero() public {
    vm.expectRevert(abi.encodeWithSelector(GasLimitIsZero.selector));
    relayer.relay(
      messageDispatcher,
      remoteOwnerChainId,
      remoteOwner,
      rngAuctionRelayListener,
      address(this),
      0
    );
  }
}
