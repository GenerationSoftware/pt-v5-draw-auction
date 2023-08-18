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

  event AuctionRewardDistributed(
    uint32 indexed sequenceId,
    address indexed recipient,
    uint32 index,
    uint256 reward
  );

  event RngSequenceCompleted(
    uint32 indexed sequenceId,
    uint32 indexed drawId
  );
  /* ============ Variables ============ */

  RngRelayAuction public rngRelayAuction;

  PrizePool prizePool;
  uint64 auctionDurationSeconds = 1 hours;
  uint64 auctionTargetTime = 1;

  address alice;

  function setUp() public {
    alice = makeAddr("alice");
    prizePool = PrizePool(makeAddr("prizePool"));
    vm.etch(address(prizePool), "prizePool");

    rngRelayAuction = new RngRelayAuction(prizePool, address(this), auctionDurationSeconds, auctionTargetTime);
  }

  function testConstructor() public {
    assertEq(rngRelayAuction.lastSequenceId(), 0);
    assertEq(rngRelayAuction.auctionDuration(), auctionDurationSeconds, "auction duration");
    assertEq(rngRelayAuction.rngAuctionRelayer(), address(this), "relayer matches");
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
    assertApproxEqAbs(rngRelayAuction.computeRewardFraction(auctionDurationSeconds).unwrap(), 1 ether, 2, "fractional reward at one");
  }

  function testIsSequenceCompleted_empty() public {
    assertFalse(rngRelayAuction.isSequenceCompleted(1));
  }

  function testRngComplete_happyPath() public {
    AuctionResult memory results = AuctionResult({
      recipient: address(this),
      rewardFraction: UD2x18.wrap(0.1 ether)
    });

    mockCloseDraw(0x1234);
    vm.mockCall(
      address(prizePool),
      abi.encodeWithSelector(prizePool.reserve.selector),
      abi.encode(100e18)
    );
    mockWithdrawReserve(address(this), 10e18);

    vm.expectEmit(true, true, true, true);
    emit RngSequenceCompleted(
      1,
      42
    );
    vm.expectEmit(true, true, true, true);
    emit AuctionRewardDistributed(
      1,
      address(this),
      0,
      10e18
    );
    vm.expectEmit(true, true, true, true);
    emit AuctionRewardDistributed(
      1,
      alice,
      1,
      22487498263889022870 // 0.25 * 90
    );
    uint completedAt = block.timestamp;
    vm.warp(completedAt + auctionDurationSeconds/2);
    rngRelayAuction.rngComplete(
      0x1234,
      completedAt,
      alice,
      1,
      results
    );

    assertEq(rngRelayAuction.lastSequenceId(), 1, "sequence id is now 1");
    assertTrue(rngRelayAuction.isSequenceCompleted(1), "sequence 1 auction is complete");

    AuctionResult memory r = rngRelayAuction.getLastAuctionResult();
    assertEq(r.recipient, alice);
    assertEq(r.rewardFraction.unwrap(), 249861091820989143, "reward fraction is about a quarter (halfway through parabola)");
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
