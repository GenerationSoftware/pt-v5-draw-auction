// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Helpers, RNGInterface, UD2x18 } from "./helpers/Helpers.t.sol";
import { AuctionResult } from "../src/interfaces/IAuction.sol";
import { RewardLib } from "../src/libraries/RewardLib.sol";

import {
  RngRelayAuction,
  PrizePool,
  RngRelayerZeroAddress,
  AuctionDurationZero,
  AuctionTargetTimeZero,
  TargetRewardFractionGTOne,
  SequenceAlreadyCompleted,
  AuctionExpired,
  PrizePoolZeroAddress,
  UnauthorizedRelayer,
  MaxRewardIsZero,
  RewardRecipientIsZeroAddress,
  AuctionTargetTimeExceedsDuration
} from "../src/RngRelayAuction.sol";

contract RngRelayAuctionTest is Helpers {
  /* ============ Mock Errors ============ */
  error MockAllocateRewardFromReserve(address to, uint256 amount);

  /* ============ Events ============ */

  event AuctionCompleted(
    address indexed recipient,
    uint32 indexed sequenceId,
    uint64 elapsedTime,
    UD2x18 rewardFraction
  );

  event AuctionRewardAllocated(
    uint32 indexed sequenceId,
    address indexed recipient,
    uint32 indexed index,
    uint256 reward
  );

  event RngSequenceCompleted(uint32 indexed sequenceId, PrizePool indexed prizePool, uint32 indexed drawId);
  /* ============ Variables ============ */

  RngRelayAuction public rngRelayAuction;
  RngRelayAuction public rngRelayAuctionWithFirstTargetReward;
  PrizePool prizePool;
  uint64 auctionDurationSeconds = 1 hours;
  uint64 auctionTargetTime = 1;
  UD2x18 firstAuctionTargetRewardFractionZero = UD2x18.wrap(uint64(0));
  uint256 maxRewards = 1000e18;

  address alice;

  function setUp() public {
    alice = makeAddr("alice");
    prizePool = PrizePool(makeAddr("prizePool"));
    vm.etch(address(prizePool), "prizePool");

    rngRelayAuction = new RngRelayAuction(
      auctionDurationSeconds,
      auctionTargetTime,
      address(this),
      firstAuctionTargetRewardFractionZero,
      maxRewards
    );
  }

  function testConstructor() public {
    assertEq(rngRelayAuction.lastSequenceId(), 0);
    assertEq(rngRelayAuction.auctionDuration(), auctionDurationSeconds, "auction duration");
    assertEq(rngRelayAuction.rngAuctionRelayer(), address(this), "relayer matches");
  }

  function testConstructor_RngRelayerZeroAddress() public {
    vm.expectRevert(abi.encodeWithSelector(RngRelayerZeroAddress.selector));
    new RngRelayAuction(
      auctionDurationSeconds,
      auctionTargetTime,
      address(0),
      firstAuctionTargetRewardFractionZero,
      maxRewards
    );
  }

  function testConstructor_AuctionDurationZero() public {
    vm.expectRevert(abi.encodeWithSelector(AuctionDurationZero.selector));
    new RngRelayAuction(
      0,
      auctionTargetTime,
      address(this),
      firstAuctionTargetRewardFractionZero,
      maxRewards
    );
  }

  function testConstructor_MaxRewardIsZero() public {
    vm.expectRevert(abi.encodeWithSelector(MaxRewardIsZero.selector));
    new RngRelayAuction(
      auctionDurationSeconds,
      auctionTargetTime,
      address(this),
      firstAuctionTargetRewardFractionZero,
      0
    );
  }

  function testConstructor_AuctionTargetTimeZero() public {
    vm.expectRevert(abi.encodeWithSelector(AuctionTargetTimeZero.selector));
    new RngRelayAuction(
      auctionDurationSeconds,
      0,
      address(this),
      firstAuctionTargetRewardFractionZero,
      maxRewards
    );
  }

  function testConstructor_AuctionTargetTimeExceedsDuration() public {
    vm.expectRevert(
      abi.encodeWithSelector(AuctionTargetTimeExceedsDuration.selector, 1 hours, 2 hours)
    );
    new RngRelayAuction(
      1 hours,
      2 hours,
      address(this),
      firstAuctionTargetRewardFractionZero,
      maxRewards
    );
  }

  function testConstructor_TargetRewardFractionGTOne() public {
    vm.expectRevert(abi.encodeWithSelector(TargetRewardFractionGTOne.selector));
    new RngRelayAuction(
      auctionDurationSeconds,
      auctionTargetTime,
      address(this),
      UD2x18.wrap(uint64(2e18)),
      maxRewards
    );
  }

  function testFractionalReward() public {
    assertEq(
      rngRelayAuction.computeRewardFraction(0).unwrap(),
      0 ether,
      "fractional reward at zero"
    );

    assertApproxEqAbs(
      rngRelayAuction.computeRewardFraction(auctionDurationSeconds).unwrap(),
      1 ether,
      2,
      "fractional reward at one"
    );
  }

  function testIsSequenceCompleted_empty() public {
    assertFalse(rngRelayAuction.isSequenceCompleted(1));
  }

  function testIsAuctionOpen_empty() public {
    assertTrue(rngRelayAuction.isAuctionOpen(1, 0));
  }

  function testIsAuctionOpen_closedWhenCompleted() public {
    mockCloseDraw(0x1234);
    mockReserve(0);
    vm.warp(10 days);
    rngRelayAuction.rngComplete(
      prizePool,
      0x1234,
      10 days,
      address(this),
      1,
      AuctionResult({ recipient: address(this), rewardFraction: UD2x18.wrap(0 ether) })
    );
    assertFalse(rngRelayAuction.isAuctionOpen(1, auctionDurationSeconds));
  }

  function testIsAuctionOpen_closedWhenExpired() public {
    assertFalse(rngRelayAuction.isAuctionOpen(0, auctionDurationSeconds));
  }

  function testRngComplete_UnauthorizedRelayer() public {
    address bob = makeAddr("bob");
    vm.startPrank(bob);
    vm.expectRevert(abi.encodeWithSelector(UnauthorizedRelayer.selector, bob));
    rngRelayAuction.rngComplete(
      prizePool,
      0x1234,
      block.timestamp,
      bob,
      1,
      AuctionResult({ recipient: address(this), rewardFraction: UD2x18.wrap(0.1 ether) })
    );
    vm.stopPrank();
  }


  function testRngComplete_PrizePoolZeroAddress() public {
    vm.expectRevert(abi.encodeWithSelector(PrizePoolZeroAddress.selector));
    rngRelayAuction.rngComplete(
      PrizePool(address(0)),
      0x1234,
      block.timestamp,
      alice,
      1,
      AuctionResult({ recipient: address(this), rewardFraction: UD2x18.wrap(0.1 ether) })
    );
  }

  function testRngComplete_happyPath() public {
    AuctionResult memory results = AuctionResult({
      recipient: address(this),
      rewardFraction: UD2x18.wrap(0.1 ether)
    });

    mockCloseDraw(0x1234);
    mockReserve(100e18);
    mockAllocateRewardFromReserve(address(this), 10e18);

    vm.expectEmit(true, true, true, true);
    emit RngSequenceCompleted(1, prizePool, 42);
    vm.expectEmit(true, true, true, true);
    emit AuctionRewardAllocated(1, address(this), 0, 10e18);
    vm.expectEmit(true, true, true, true);
    emit AuctionRewardAllocated(
      1,
      alice,
      1,
      22487498263889022870 // 0.25 * 90
    );
    uint256 completedAt = block.timestamp;
    vm.warp(completedAt + auctionDurationSeconds / 2);
    rngRelayAuction.rngComplete(prizePool, 0x1234, completedAt, alice, 1, results);

    assertEq(rngRelayAuction.lastSequenceId(), 1, "sequence id is now 1");
    assertTrue(rngRelayAuction.isSequenceCompleted(1), "sequence 1 auction is complete");

    AuctionResult memory r = rngRelayAuction.getLastAuctionResult();
    assertEq(r.recipient, alice);
    assertEq(
      r.rewardFraction.unwrap(),
      249861091820989143,
      "reward fraction is about a quarter (halfway through parabola)"
    );
  }

  function testRngComplete_rewardsAllocated() public {
    AuctionResult memory results = AuctionResult({
      recipient: address(this),
      rewardFraction: UD2x18.wrap(0.1 ether)
    });

    mockCloseDraw(0x1234);
    mockReserve(100e18);
    uint256 completedAt = block.timestamp;
    vm.warp(completedAt + auctionDurationSeconds / 2);

    vm.mockCallRevert(
      address(prizePool),
      abi.encodeWithSelector(
        prizePool.allocateRewardFromReserve.selector,
        alice,
        22487498263889022870
      ),
      abi.encodeWithSelector(MockAllocateRewardFromReserve.selector, alice, 22487498263889022870)
    );
    vm.expectRevert(
      abi.encodeWithSelector(MockAllocateRewardFromReserve.selector, alice, 22487498263889022870)
    );
    rngRelayAuction.rngComplete(prizePool, 0x1234, completedAt, alice, 1, results);
  }

  function testRngComplete_maxRewards() public {
    rngRelayAuction = new RngRelayAuction(
      auctionDurationSeconds,
      auctionTargetTime,
      address(this),
      firstAuctionTargetRewardFractionZero,
      10e18
    );

    AuctionResult memory results = AuctionResult({
      recipient: address(this),
      rewardFraction: UD2x18.wrap(0.1 ether)
    });

    mockCloseDraw(0x1234);
    mockReserve(100e18);
    mockAllocateRewardFromReserve(address(this), 1e18);

    vm.expectEmit(true, true, true, true);
    emit AuctionRewardAllocated(1, address(this), 0, 1e18);
    vm.expectEmit(true, true, true, true);
    emit AuctionRewardAllocated(1, alice, 1, 2.248749826388902287e18);

    uint256 completedAt = block.timestamp;
    vm.warp(completedAt + auctionDurationSeconds / 2);
    rngRelayAuction.rngComplete(prizePool, 0x1234, completedAt, alice, 1, results);

    assertEq(rngRelayAuction.lastSequenceId(), 1, "sequence id is now 1");
    assertTrue(rngRelayAuction.isSequenceCompleted(1), "sequence 1 auction is complete");

    AuctionResult memory r = rngRelayAuction.getLastAuctionResult();
    assertEq(r.recipient, alice);
    assertEq(
      r.rewardFraction.unwrap(),
      249861091820989143,
      "reward fraction is about a quarter (halfway through parabola)"
    );
  }

  function testRngComplete_FirstAuctionTargetRewardFractionSet() public {
    UD2x18 firstAuctionTargetRewardFraction = UD2x18.wrap(uint64(0.1e18));

    rngRelayAuctionWithFirstTargetReward = new RngRelayAuction(
      auctionDurationSeconds,
      auctionTargetTime,
      address(this),
      firstAuctionTargetRewardFraction,
      maxRewards
    );

    AuctionResult memory results = AuctionResult({
      recipient: address(this),
      rewardFraction: firstAuctionTargetRewardFraction
    });

    uint256 reserve = 100e18;
    uint256 allocatedReward = 10e18;

    mockCloseDraw(0x1234);
    mockReserve(reserve);
    mockAllocateRewardFromReserve(address(this), allocatedReward);

    vm.expectEmit(true, true, true, true);
    emit RngSequenceCompleted(1, prizePool, 42);

    vm.expectEmit(true, true, true, true);
    emit AuctionRewardAllocated(1, address(this), 0, allocatedReward);

    vm.expectEmit(true, true, true, true);
    emit AuctionRewardAllocated(1, alice, 1, 2.9238748437500120520e19);

    uint256 completedAt = block.timestamp;
    vm.warp(completedAt + auctionDurationSeconds / 2);
    rngRelayAuctionWithFirstTargetReward.rngComplete(prizePool, 0x1234, completedAt, alice, 1, results);

    assertEq(rngRelayAuctionWithFirstTargetReward.lastSequenceId(), 1, "sequence id is now 1");
    assertTrue(
      rngRelayAuctionWithFirstTargetReward.isSequenceCompleted(1),
      "sequence 1 auction is complete"
    );

    AuctionResult memory r = rngRelayAuctionWithFirstTargetReward.getLastAuctionResult();
    assertEq(r.recipient, alice);
    assertEq(r.rewardFraction.unwrap(), 3.24874982638890228e17);
  }

  function testRngComplete_SequenceAlreadyCompleted() public {
    AuctionResult memory results = AuctionResult({
      recipient: address(this),
      rewardFraction: UD2x18.wrap(0.1 ether)
    });

    mockCloseDraw(0x1234);
    mockPrizePoolReserve(100e18);
    mockAllocateRewardFromReserve(address(this), 10e18);

    rngRelayAuction.rngComplete(prizePool, 0x1234, block.timestamp, address(this), 1, results);

    vm.expectRevert(abi.encodeWithSelector(SequenceAlreadyCompleted.selector));
    rngRelayAuction.rngComplete(prizePool, 0x1234, block.timestamp, address(this), 1, results);
  }

  function testRngComplete_AuctionExpired() public {
    AuctionResult memory results = AuctionResult({
      recipient: address(this),
      rewardFraction: UD2x18.wrap(0.1 ether)
    });

    vm.warp(auctionDurationSeconds + 1);
    vm.expectRevert(abi.encodeWithSelector(AuctionExpired.selector));
    rngRelayAuction.rngComplete(prizePool, 0x1234, 0, address(this), 1, results);
  }

  function testRngComplete_RewardRecipientIsZeroAddress() public {
    AuctionResult memory results = AuctionResult({
      recipient: alice,
      rewardFraction: UD2x18.wrap(0.1 ether)
    });

    mockCloseDraw(0x1234);
    mockReserve(100e18);
    mockAllocateRewardFromReserve(address(this), 10e18);

    uint256 completedAt = block.timestamp;
    vm.warp(completedAt + auctionDurationSeconds / 2);

    vm.expectRevert(abi.encodeWithSelector(RewardRecipientIsZeroAddress.selector));
    rngRelayAuction.rngComplete(prizePool, 0x1234, completedAt, address(0), 1, results);
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
    uint256[] memory rewards = rngRelayAuction.computeRewards(prizePool, results);

    assertEq(rewards[0], 10e18, "reward 0");
    assertEq(rewards[1], 45e18, "reward 1");
  }

  function testComputeRewards_maxRewards() public {
    rngRelayAuction = new RngRelayAuction(
      auctionDurationSeconds,
      auctionTargetTime,
      address(this),
      firstAuctionTargetRewardFractionZero,
      10e18
    );

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
    uint256[] memory rewards = rngRelayAuction.computeRewards(prizePool, results);

    assertEq(rewards[0], 1e18, "reward 0");
    assertEq(rewards[1], 4.5e18, "reward 1");
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
    uint256 half = amount / 2;
    vm.mockCall(
      address(prizePool),
      abi.encodeWithSelector(prizePool.reserve.selector),
      abi.encode(half)
    );
    vm.mockCall(
      address(prizePool),
      abi.encodeWithSelector(prizePool.pendingReserveContributions.selector),
      abi.encode(amount - half)
    );
  }

  function mockAllocateRewardFromReserve(address recipient, uint256 amount) public {
    vm.mockCall(
      address(prizePool),
      abi.encodeWithSelector(PrizePool.allocateRewardFromReserve.selector, recipient, amount),
      abi.encode()
    );
  }

  function mockCloseDraw(uint256 randomNumber) public {
    vm.mockCall(
      address(prizePool),
      abi.encodeWithSelector(PrizePool.awardDraw.selector, randomNumber),
      abi.encode(42)
    );
  }

  function mockReserve(uint256 value) public {
    vm.mockCall(
      address(prizePool),
      abi.encodeWithSelector(prizePool.reserve.selector),
      abi.encode(value)
    );
  }
}
