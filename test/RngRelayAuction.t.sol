// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Helpers, RNGInterface, UD2x18 } from "./helpers/Helpers.t.sol";
import { AuctionResult } from "../src/interfaces/IAuction.sol";

import {
  RngRelayAuction,
  PrizePool,
  RngRelayerZeroAddress,
  AuctionDurationZero,
  AuctionTargetTimeZero,
  SequenceAlreadyCompleted,
  AuctionExpired,
  PrizePoolZeroAddress,
  UnauthorizedRelayer,
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

  RngRelayAuction public rngRelayAuction;

  PrizePool prizePool;
  uint64 auctionDurationSeconds = 1 hours;
  uint64 auctionTargetTime = 15 minutes;

  function setUp() public {
    prizePool = PrizePool(makeAddr("prizePool"));
    vm.etch(address(prizePool), "prizePool");

    rngRelayAuction = new RngRelayAuction(prizePool, address(this), auctionDurationSeconds, auctionTargetTime);
  }

  function testConstructor() public {
    assertEq(rngRelayAuction.lastSequenceId(), 0);
    assertEq(rngRelayAuction.auctionDuration(), auctionDurationSeconds, "auction duration");
    assertEq(rngRelayAuction.computeRewardFraction(auctionDurationSeconds).unwrap(), 1 ether, "fractional reward");
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
    assertEq(rngRelayAuction.computeRewardFraction(0).unwrap(), 0 ether, "fractional reward at zero");
    assertEq(rngRelayAuction.computeRewardFraction(auctionDurationSeconds).unwrap(), 1 ether, "fractional reward at one");
  }

  function testRngComplete_UnauthorizedRelayer() public {
    address bob = makeAddr("bob");
    vm.startPrank(bob);
    vm.expectRevert(abi.encodeWithSelector(UnauthorizedRelayer.selector, bob));
    rngRelayAuction.rngComplete(
      0x1234,
      block.timestamp,
      bob,
      1,
      AuctionResult({
        recipient: address(this),
        rewardFraction: UD2x18.wrap(0.1 ether)
      })
    );
    vm.stopPrank();
  }

  function testRngComplete_happyPath() public {
    AuctionResult memory results = AuctionResult({
      recipient: address(this),
      rewardFraction: UD2x18.wrap(0.1 ether)
    });

    assertFalse(rngRelayAuction.isSequenceCompleted(1));

    mockCloseDraw(0x1234);
    mockPrizePoolReserve(100e18);
    mockWithdrawReserve(address(this), 10e18);

    rngRelayAuction.rngComplete(
      0x1234,
      block.timestamp,
      address(this),
      1,
      results
    );

    assertEq(rngRelayAuction.lastSequenceId(), 1, "sequence id is now 1");
    assertTrue(rngRelayAuction.isSequenceCompleted(1), "sequence 1 auction is complete");

    AuctionResult memory r = rngRelayAuction.getLastAuctionResult();
    assertEq(r.recipient, address(this));
    assertEq(r.rewardFraction.unwrap(), 0 ether, "reward fraction is 0 ether");
  }

  function testRngComplete_SequenceAlreadyCompleted() public {
    AuctionResult memory results = AuctionResult({
      recipient: address(this),
      rewardFraction: UD2x18.wrap(0.1 ether)
    });

    mockCloseDraw(0x1234);
    mockPrizePoolReserve(100e18);
    mockWithdrawReserve(address(this), 10e18);

    rngRelayAuction.rngComplete(
      0x1234,
      block.timestamp,
      address(this),
      1,
      results
    );

    vm.expectRevert(abi.encodeWithSelector(SequenceAlreadyCompleted.selector));
    rngRelayAuction.rngComplete(
      0x1234,
      block.timestamp,
      address(this),
      1,
      results
    );
  }

  function testRngComplete_AuctionExpired() public {
    AuctionResult memory results = AuctionResult({
      recipient: address(this),
      rewardFraction: UD2x18.wrap(0.1 ether)
    });

    vm.warp(auctionDurationSeconds);
    vm.expectRevert(abi.encodeWithSelector(AuctionExpired.selector));
    rngRelayAuction.rngComplete(
      0x1234,
      0,
      address(this),
      1,
      results
    );
  }

  function testComputeRewards() public {
    AuctionResult[] memory results = new AuctionResult[](2);
    results[0] = AuctionResult({
      recipient: address(this),
      rewardFraction: UD2x18.wrap(0.1 ether)
    });
    results[1] = AuctionResult({
      recipient: address(this),
      rewardFraction: UD2x18.wrap(0.5 ether)
    });

    mockPrizePoolReserve(100e18);
    uint256[] memory rewards = rngRelayAuction.computeRewards(results);

    assertEq(rewards[0], 10e18, "reward 0");
    assertEq(rewards[1], 45e18, "reward 1");
  }

  function testComputeRewardsWithTotal() public {
    AuctionResult[] memory results = new AuctionResult[](2);
    results[0] = AuctionResult({
      recipient: address(this),
      rewardFraction: UD2x18.wrap(0.1 ether)
    });
    results[1] = AuctionResult({
      recipient: address(this),
      rewardFraction: UD2x18.wrap(0.5 ether)
    });

    uint256[] memory rewards = rngRelayAuction.computeRewardsWithTotal(results, 100e18);

    assertEq(rewards[0], 10e18, "reward 0");
    assertEq(rewards[1], 45e18, "reward 1");
  }

  /* ============ mock ============ */

  function mockPrizePoolReserve(uint256 amount) public {
    uint half = amount / 2;
    vm.mockCall(
      address(prizePool),
      abi.encodeWithSelector(prizePool.reserve.selector),
      abi.encode(half)
    );
    vm.mockCall(
      address(prizePool),
      abi.encodeWithSelector(prizePool.reserveForOpenDraw.selector),
      abi.encode(amount - half)
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
