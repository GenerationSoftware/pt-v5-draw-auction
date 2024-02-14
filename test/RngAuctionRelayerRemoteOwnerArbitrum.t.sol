// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import { PrizePool } from "pt-v5-prize-pool/PrizePool.sol";
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
  RngAuctionRelayerRemoteOwnerArbitrum,
  ArbitrumRelayParams,
  IMessageDispatcherArbitrum,
  RemoteOwner,
  MessageDispatcherIsZeroAddress,
  RemoteOwnerIsZeroAddress,
  RemoteRngAuctionRelayListenerIsZeroAddress,
  GasLimitIsLTEOne,
  GasPriceBidIsLTEOne,
  RemoteOwnerCallEncoder
} from "../src/RngAuctionRelayerRemoteOwnerArbitrum.sol";

contract RngAuctionRelayerRemoteOwnerArbitrumTest is RngRelayerBaseTest {
  event RelayedToDispatcher(
    IMessageDispatcherArbitrum messageDispatcher,
    uint256 indexed remoteOwnerChainId,
    RemoteOwner remoteOwner,
    IRngAuctionRelayListener remoteRngAuctionRelayListener,
    PrizePool remotePrizePool,
    address indexed rewardRecipient,
    bytes32 indexed messageId
  );

  RngAuctionRelayerRemoteOwnerArbitrum public relayer;
  PrizePool prizePool = PrizePool(makeAddr("prizePool"));
  IMessageDispatcherArbitrum public messageDispatcher;
  RemoteOwner public remoteOwner;
  uint256 public remoteOwnerChainId = 1;
  uint256 public gasLimit = 250_000;
  uint256 public maxSubmissionCost = 17589493504;
  uint256 public gasPriceBid = 100000000;

  function setUp() public override {
    super.setUp();
    messageDispatcher = IMessageDispatcherArbitrum(makeAddr("messageDispatcher"));
    remoteOwner = RemoteOwner(payable(makeAddr("remoteOwner")));

    relayer = new RngAuctionRelayerRemoteOwnerArbitrum(rngAuction);
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
        prizePool,
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
    uint256 value = 1e16; // payable value passed along

    vm.mockCall(
      address(messageDispatcher),
      value,
      abi.encodeWithSelector(
        IMessageDispatcherArbitrum.dispatchAndProcessMessage.selector,
        remoteOwnerChainId,
        remoteOwner,
        data,
        address(this),
        gasLimit,
        maxSubmissionCost,
        gasPriceBid
      ),
      abi.encode(messageId, uint256(123456))
    );

    vm.expectEmit(true, true, false, false);

    emit RelayedToDispatcher(
      messageDispatcher,
      remoteOwnerChainId,
      remoteOwner,
      rngAuctionRelayListener,
      prizePool,
      address(this),
      messageId
    );

    assertEq(
      relayer.relay{ value: value }(
        messageDispatcher,
        remoteOwnerChainId,
        remoteOwner,
        rngAuctionRelayListener,
        prizePool,
        address(this),
        ArbitrumRelayParams(
          address(this),
          gasLimit,
          maxSubmissionCost,
          gasPriceBid
        )
      ),
      messageId
    );
  }

  function testRelay_MessageDispatcherIsZeroAddress() public {
    vm.expectRevert(abi.encodeWithSelector(MessageDispatcherIsZeroAddress.selector));
    relayer.relay(
      IMessageDispatcherArbitrum(address(0)),
      remoteOwnerChainId,
      remoteOwner,
      rngAuctionRelayListener,
      prizePool,
      address(this),
      ArbitrumRelayParams(
        address(this),
        gasLimit,
        maxSubmissionCost,
        gasPriceBid
      )
    );
  }

  function testRelay_RemoteOwnerIsZeroAddress() public {
    vm.expectRevert(abi.encodeWithSelector(RemoteOwnerIsZeroAddress.selector));
    relayer.relay(
      messageDispatcher,
      remoteOwnerChainId,
      RemoteOwner(payable(0)),
      rngAuctionRelayListener,
      prizePool,
      address(this),
      ArbitrumRelayParams(
        address(this),
        gasLimit,
        maxSubmissionCost,
        gasPriceBid
      )
    );
  }

  function testRelay_RemoteRngAuctionRelayListenerIsZeroAddress() public {
    vm.expectRevert(abi.encodeWithSelector(RemoteRngAuctionRelayListenerIsZeroAddress.selector));
    relayer.relay(
      messageDispatcher,
      remoteOwnerChainId,
      remoteOwner,
      IRngAuctionRelayListener(address(0)),
      prizePool,
      address(this),
      ArbitrumRelayParams(
        address(this),
        gasLimit,
        maxSubmissionCost,
        gasPriceBid
      )
    );
  }

  function testRelay_RewardRecipientIsZeroAddress() public {
    vm.expectRevert(abi.encodeWithSelector(RewardRecipientIsZeroAddress.selector));
    relayer.relay(
      messageDispatcher,
      remoteOwnerChainId,
      remoteOwner,
      rngAuctionRelayListener,
      prizePool,
      address(0),
      ArbitrumRelayParams(
        address(this),
        gasLimit,
        maxSubmissionCost,
        gasPriceBid
      )
    );
  }

  function testRelay_GasLimitIsLTEOne() public {
    vm.expectRevert(abi.encodeWithSelector(GasLimitIsLTEOne.selector));
    relayer.relay(
      messageDispatcher,
      remoteOwnerChainId,
      remoteOwner,
      rngAuctionRelayListener,
      prizePool,
      address(this),
      ArbitrumRelayParams(
        address(this),
        1,
        maxSubmissionCost,
        gasPriceBid
      )
    );
  }

  function testRelay_GasPriceBidIsLTEOne() public {
    vm.expectRevert(abi.encodeWithSelector(GasPriceBidIsLTEOne.selector));
    relayer.relay(
      messageDispatcher,
      remoteOwnerChainId,
      remoteOwner,
      rngAuctionRelayListener,
      prizePool,
      address(this),
      ArbitrumRelayParams(
        address(this),
        gasLimit,
        maxSubmissionCost,
        1
      )
    );
  }
}
