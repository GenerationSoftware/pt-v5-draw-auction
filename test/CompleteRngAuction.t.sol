// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Helpers, RNGInterface, UD2x18, AuctionResults } from "./helpers/Helpers.t.sol";

import {
  CompleteRngAuction,
  DrawManagerZeroAddress,
  RngRelayerZeroAddress,
  AuctionDurationZero,
  AuctionTargetTimeZero,
  SequenceAlreadyCompleted,
  AuctionExpired,
  AuctionTargetTimeExceedsDuration
} from "../src/CompleteRngAuction.sol";

import { DrawManager } from "../src/DrawManager.sol";

contract CompleteRngAuctionTest is Helpers {

  /* ============ Events ============ */

  event AuctionCompleted(
    address indexed recipient,
    uint32 indexed sequenceId,
    uint64 elapsedTime,
    UD2x18 rewardFraction
  );

  /* ============ Variables ============ */

  CompleteRngAuction public completeRngAuction;

  DrawManager drawManager;
  address startRngAuctionRelayer;
  uint64 auctionDurationSeconds = 1 hours;
  uint64 auctionTargetTime = 15 minutes;

  function setUp() public {
    drawManager = DrawManager(makeAddr("rngAuction"));
    vm.etch(address(drawManager), "drawManager");

    completeRngAuction = new CompleteRngAuction(drawManager, address(this), auctionDurationSeconds, auctionTargetTime);
  }

  function testConstructor() public {
    assertEq(completeRngAuction.sequenceId(), 0);
    assertEq(completeRngAuction.auctionDuration(), auctionDurationSeconds, "auction duration");
    assertEq(completeRngAuction.fractionalReward(auctionDurationSeconds).unwrap(), 1 ether, "fractional reward");
  }

  function testConstructor_DrawManagerZeroAddress() public {
    vm.expectRevert(abi.encodeWithSelector(DrawManagerZeroAddress.selector));
    new CompleteRngAuction(DrawManager(address(0)), address(this), auctionDurationSeconds, auctionTargetTime);
  }

  function testConstructor_RngRelayerZeroAddress() public {
    vm.expectRevert(abi.encodeWithSelector(RngRelayerZeroAddress.selector));
    new CompleteRngAuction(drawManager, address(0), auctionDurationSeconds, auctionTargetTime);
  }

  function testConstructor_AuctionDurationZero() public {
    vm.expectRevert(abi.encodeWithSelector(AuctionDurationZero.selector));
    new CompleteRngAuction(drawManager, address(this), 0, auctionTargetTime);
  }

  function testConstructor_AuctionTargetTimeZero() public {
    vm.expectRevert(abi.encodeWithSelector(AuctionTargetTimeZero.selector));
    new CompleteRngAuction(drawManager, address(this), auctionDurationSeconds, 0);
  }

  function testConstructor_AuctionTargetTimeExceedsDuration() public {
    vm.expectRevert(abi.encodeWithSelector(AuctionTargetTimeExceedsDuration.selector, 1 hours, 2 hours));
    new CompleteRngAuction(drawManager, address(this), 1 hours, 2 hours);
  }

  function testFractionalReward() public {
    assertEq(completeRngAuction.fractionalReward(0).unwrap(), 0 ether, "fractional reward at zero");
    assertEq(completeRngAuction.fractionalReward(auctionDurationSeconds).unwrap(), 1 ether, "fractional reward at one");
  }

  function testRngComplete_happyPath() public {
    AuctionResults memory results = AuctionResults({
      recipient: address(this),
      rewardFraction: UD2x18.wrap(0.1 ether)
    });

    mockCloseDraw(0x1234, address(this), UD2x18.wrap(0.1 ether), address(this), UD2x18.wrap(0));

    assertFalse(completeRngAuction.isAuctionComplete(1));

    completeRngAuction.rngComplete(
      0x1234,
      block.timestamp,
      address(this),
      1,
      results
    );

    assertEq(completeRngAuction.sequenceId(), 1, "sequence id is now 1");
    assertTrue(completeRngAuction.isAuctionComplete(1), "sequence 1 auction is complete");

    AuctionResults memory r = completeRngAuction.getAuctionResults();
    assertEq(r.recipient, address(this));
    assertEq(r.rewardFraction.unwrap(), 0 ether, "reward fraction is 0 ether");
  }

  function testRngComplete_SequenceAlreadyCompleted() public {
    AuctionResults memory results = AuctionResults({
      recipient: address(this),
      rewardFraction: UD2x18.wrap(0.1 ether)
    });

    mockCloseDraw(0x1234, address(this), UD2x18.wrap(0.1 ether), address(this), UD2x18.wrap(0));

    completeRngAuction.rngComplete(
      0x1234,
      block.timestamp,
      address(this),
      1,
      results
    );

    vm.expectRevert(abi.encodeWithSelector(SequenceAlreadyCompleted.selector));
    completeRngAuction.rngComplete(
      0x1234,
      block.timestamp,
      address(this),
      1,
      results
    );
  }

  function testRngComplete_AuctionExpired() public {
    AuctionResults memory results = AuctionResults({
      recipient: address(this),
      rewardFraction: UD2x18.wrap(0.1 ether)
    });

    vm.warp(auctionDurationSeconds);
    vm.expectRevert(abi.encodeWithSelector(AuctionExpired.selector));
    completeRngAuction.rngComplete(
      0x1234,
      0,
      address(this),
      1,
      results
    );
  }


  /* ============ mock ============ */

  function mockCloseDraw(uint256 randomNumber, address recipient1, UD2x18 reward1, address recipient2, UD2x18 reward2) public {
    AuctionResults[] memory _results = new AuctionResults[](2);
    _results[0] = AuctionResults({
      recipient: recipient1,
      rewardFraction: reward1
    });
    _results[1] = AuctionResults({
      recipient: recipient2,
      rewardFraction: reward2
    });

    vm.mockCall(
      address(drawManager),
      abi.encodeWithSelector(DrawManager.closeDraw.selector, randomNumber, _results),
      abi.encode(42)
    );
  }

}
