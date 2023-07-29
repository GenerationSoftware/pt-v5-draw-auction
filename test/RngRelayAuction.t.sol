// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Helpers, RNGInterface, UD2x18, AuctionResults } from "./helpers/Helpers.t.sol";

import {
  RngRelayAuction,
  PrizePool,
  RngRelayerZeroAddress,
  AuctionDurationZero,
  AuctionTargetTimeZero,
  SequenceAlreadyCompleted,
  AuctionExpired,
  PrizePoolZeroAddress,
  AuctionTargetTimeExceedsDuration
} from "../src/RngRelayAuction.sol";

contract RngRelayAuctionTest is Helpers {

  /* ============ Events ============ */

  event AuctionCompleted(
    address indexed recipient,
    uint32 indexed sequenceId,
    uint64 elapsedTime,
    UD2x18 rewardFraction
  );

  /* ============ Variables ============ */

  RngRelayAuction public completeRngAuction;

  PrizePool prizePool;
  address startRngAuctionRelayer;
  uint64 auctionDurationSeconds = 1 hours;
  uint64 auctionTargetTime = 15 minutes;

  function setUp() public {
    prizePool = PrizePool(makeAddr("prizePool"));
    vm.etch(address(prizePool), "prizePool");

    completeRngAuction = new RngRelayAuction(prizePool, address(this), auctionDurationSeconds, auctionTargetTime);
  }

  function testConstructor() public {
    assertEq(completeRngAuction.sequenceId(), 0);
    assertEq(completeRngAuction.auctionDuration(), auctionDurationSeconds, "auction duration");
    assertEq(completeRngAuction.fractionalReward(auctionDurationSeconds).unwrap(), 1 ether, "fractional reward");
  }

  function testConstructor_PrizePoolZeroAddress() public {
    vm.expectRevert(abi.encodeWithSelector(PrizePoolZeroAddress.selector));
    new RngRelayAuction(PrizePool(address(0)), address(this), auctionDurationSeconds, auctionTargetTime);
  }

  function testConstructor_RngRelayerZeroAddress() public {
    vm.expectRevert(abi.encodeWithSelector(RngRelayerZeroAddress.selector));
    new RngRelayAuction(prizePool, address(0), auctionDurationSeconds, auctionTargetTime);
  }

  function testConstructor_AuctionDurationZero() public {
    vm.expectRevert(abi.encodeWithSelector(AuctionDurationZero.selector));
    new RngRelayAuction(prizePool, address(this), 0, auctionTargetTime);
  }

  function testConstructor_AuctionTargetTimeZero() public {
    vm.expectRevert(abi.encodeWithSelector(AuctionTargetTimeZero.selector));
    new RngRelayAuction(prizePool, address(this), auctionDurationSeconds, 0);
  }

  function testConstructor_AuctionTargetTimeExceedsDuration() public {
    vm.expectRevert(abi.encodeWithSelector(AuctionTargetTimeExceedsDuration.selector, 1 hours, 2 hours));
    new RngRelayAuction(prizePool, address(this), 1 hours, 2 hours);
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

    assertFalse(completeRngAuction.isAuctionComplete(1));

    mockCloseDraw(0x1234);
    mockPrizePoolReserve(100e18);
    mockWithdrawReserve(address(this), 10e18);

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

    mockCloseDraw(0x1234);
    mockPrizePoolReserve(100e18);
    mockWithdrawReserve(address(this), 10e18);

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

  function mockPrizePoolReserve(uint256 amount) public {
    vm.mockCall(
      address(prizePool),
      abi.encodeWithSelector(prizePool.reserve.selector),
      abi.encode(amount)
    );
  }

  function mockWithdrawReserve(address recipient, uint256 amount) public {
    vm.mockCall(
      address(prizePool),
      abi.encodeWithSelector(PrizePool.withdrawReserve.selector, recipient, amount),
      abi.encode()
    );
  }

  function mockCloseDraw(uint256 randomNumber) public {
    vm.mockCall(
      address(prizePool),
      abi.encodeWithSelector(PrizePool.closeDraw.selector, randomNumber),
      abi.encode(42)
    );
  }

}
