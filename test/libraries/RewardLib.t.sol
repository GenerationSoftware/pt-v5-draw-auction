// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { ERC20Mock } from "openzeppelin/mocks/ERC20Mock.sol";

import { UD2x18, SD1x18, ConstructorParams, PrizePool, TieredLiquidityDistributor, TwabController } from "v5-prize-pool/PrizePool.sol";

import { Helpers, RNGInterface } from "test/helpers/Helpers.t.sol";
import { RewardLibHarness } from "test/harness/RewardLibHarness.sol";

contract RewardLibTest is Helpers {
  /* ============ Variables ============ */
  RewardLibHarness public rewardLib;
  PrizePool public prizePool;
  ERC20Mock public prizeToken;

  uint32 public auctionDuration = 3 hours;
  uint32 public drawPeriodSeconds = 1 days;
  address public recipient = address(this);

  /* ============ SetUp ============ */
  function setUp() public {
    vm.warp(0);

    prizePool = new PrizePool(
      ConstructorParams({
        prizeToken: prizeToken,
        twabController: TwabController(address(0)),
        drawManager: address(0),
        grandPrizePeriodDraws: uint32(365),
        drawPeriodSeconds: drawPeriodSeconds,
        firstDrawStartsAt: uint64(block.timestamp),
        numberOfTiers: uint8(3), // minimum number of tiers
        tierShares: 100,
        canaryShares: 10,
        reserveShares: 10,
        claimExpansionThreshold: UD2x18.wrap(0.9e18), // claim threshold of 90%
        smoothing: SD1x18.wrap(0.9e18) // alpha
      })
    );

    rewardLib = new RewardLibHarness(prizePool, 2, auctionDuration);
  }

  /* ============ Reward ============ */

  /* ============ Before or at Draw ends (default state) ============ */
  function testRewardBeforeDrawEnds() public {
    assertEq(block.timestamp, 0);
    assertEq(prizePool.nextDrawEndsAt(), drawPeriodSeconds);

    assertEq(rewardLib.reward(0), 0);
    assertEq(rewardLib.reward(1), 0);
  }

  function testRewardAtDrawEnds() public {
    vm.warp(drawPeriodSeconds);

    assertEq(block.timestamp, drawPeriodSeconds);
    assertEq(prizePool.nextDrawEndsAt(), drawPeriodSeconds);

    assertEq(rewardLib.reward(0), 0);
    assertEq(rewardLib.reward(1), 0);
  }

  /* ============ Half Time ============ */
  /* ============ Phase 0 ============ */
  function testPhase0RewardAtHalfTime() public {
    uint256 _warpTimestamp = drawPeriodSeconds + (auctionDuration / 2);
    vm.warp(_warpTimestamp);

    assertEq(block.timestamp, _warpTimestamp);
    assertEq(prizePool.nextDrawEndsAt(), drawPeriodSeconds);

    uint256 _reserveAmount = 200e18;
    _mockReserves(address(prizePool), _reserveAmount);

    assertEq(rewardLib.reward(0), _reserveAmount / 2);
  }

  function testPhase0RewardSetAtHalfTime() public {
    uint256 _warpTimestamp = drawPeriodSeconds + (auctionDuration / 2);
    vm.warp(_warpTimestamp);

    assertEq(block.timestamp, _warpTimestamp);
    assertEq(prizePool.nextDrawEndsAt(), drawPeriodSeconds);

    uint256 _reserveAmount = 200e18;
    _mockReserves(address(prizePool), _reserveAmount);

    uint8 _phaseId = 0;
    rewardLib.setPhase(_phaseId, drawPeriodSeconds, uint64(_warpTimestamp), recipient);

    vm.warp(drawPeriodSeconds + auctionDuration);

    assertEq(rewardLib.reward(_phaseId), _reserveAmount / 2);
  }

  /* ============ At or After auction ends ============ */
  /* ============ Phase 0 ============ */
  function testPhase0RewardAtAuctionEnd() public {
    uint256 _warpTimestamp = drawPeriodSeconds + auctionDuration;
    vm.warp(_warpTimestamp);

    assertEq(block.timestamp, _warpTimestamp);
    assertEq(prizePool.nextDrawEndsAt(), drawPeriodSeconds);

    uint256 _reserveAmount = 200e18;
    _mockReserves(address(prizePool), _reserveAmount);

    assertEq(rewardLib.reward(0), _reserveAmount);
  }

  function testPhase0RewardSetAtAuctionEnd() public {
    uint256 _warpTimestamp = drawPeriodSeconds + auctionDuration;
    vm.warp(_warpTimestamp);

    assertEq(block.timestamp, _warpTimestamp);
    assertEq(prizePool.nextDrawEndsAt(), drawPeriodSeconds);

    uint256 _reserveAmount = 200e18;
    _mockReserves(address(prizePool), _reserveAmount);

    uint8 _phaseId = 0;
    rewardLib.setPhase(_phaseId, drawPeriodSeconds, uint64(_warpTimestamp), recipient);

    vm.warp(drawPeriodSeconds + auctionDuration * 2);

    assertEq(rewardLib.reward(_phaseId), _reserveAmount);
  }

  function testPhase0RewardAfterAuctionEnd() public {
    uint256 _warpTimestamp = drawPeriodSeconds + auctionDuration * 2;
    vm.warp(_warpTimestamp);

    assertEq(block.timestamp, _warpTimestamp);
    assertEq(prizePool.nextDrawEndsAt(), drawPeriodSeconds);

    uint256 _reserveAmount = 200e18;
    _mockReserves(address(prizePool), _reserveAmount);

    assertEq(rewardLib.reward(0), _reserveAmount);
  }

  function testPhase0RewardSetAfterAuctionEnd() public {
    uint256 _warpTimestamp = drawPeriodSeconds + auctionDuration * 2;
    vm.warp(_warpTimestamp);

    assertEq(block.timestamp, _warpTimestamp);
    assertEq(prizePool.nextDrawEndsAt(), drawPeriodSeconds);

    uint256 _reserveAmount = 200e18;
    _mockReserves(address(prizePool), _reserveAmount);

    uint8 _phaseId = 0;
    rewardLib.setPhase(_phaseId, drawPeriodSeconds, uint64(_warpTimestamp), recipient);

    vm.warp(drawPeriodSeconds + drawPeriodSeconds / 2);

    assertEq(rewardLib.reward(0), _reserveAmount);
  }

  /* ============ At or After draw period (end of second draw) ============ */
  /* ============ Phase 0 ============ */
  function testPhase0RewardAtDrawPeriodEnd() public {
    uint256 _warpTimestamp = drawPeriodSeconds * 2;
    vm.warp(_warpTimestamp);

    assertEq(block.timestamp, _warpTimestamp);
    assertEq(prizePool.nextDrawEndsAt(), drawPeriodSeconds * 2);

    uint256 _reserveAmount = 400e18;
    _mockReserves(address(prizePool), _reserveAmount);

    // Auction has restarted for new draw, so reward should be 0
    assertEq(rewardLib.reward(0), 0);
  }

  function testPhase0RewardSetAtDrawPeriodEnd() public {
    uint256 _warpTimestamp = drawPeriodSeconds * 2;
    vm.warp(_warpTimestamp);

    assertEq(block.timestamp, _warpTimestamp);
    assertEq(prizePool.nextDrawEndsAt(), drawPeriodSeconds * 2);

    uint256 _reserveAmount = 400e18;
    _mockReserves(address(prizePool), _reserveAmount);

    uint8 _phaseId = 0;
    rewardLib.setPhase(_phaseId, drawPeriodSeconds, uint64(_warpTimestamp), recipient);

    vm.warp(drawPeriodSeconds * 2 + auctionDuration);

    // Recorded phase start time is before the beginning of the auction, so reward should be 0
    assertEq(rewardLib.reward(0), 0);
  }

  function testPhase0RewardAfterDrawPeriodEnd() public {
    uint256 _warpTimestamp = drawPeriodSeconds * 2 + (auctionDuration / 2);
    vm.warp(_warpTimestamp);

    assertEq(block.timestamp, _warpTimestamp);
    assertEq(prizePool.nextDrawEndsAt(), drawPeriodSeconds * 2);

    uint256 _reserveAmount = 400e18;
    _mockReserves(address(prizePool), _reserveAmount);

    // A new auction has started, so reward should be half the reserve amount
    assertEq(rewardLib.reward(0), _reserveAmount / 2);
  }

  function testPhase0RewardSetAfterDrawPeriodEnd() public {
    uint256 _warpTimestamp = drawPeriodSeconds * 2 + (auctionDuration / 2);
    vm.warp(_warpTimestamp);

    assertEq(block.timestamp, _warpTimestamp);
    assertEq(prizePool.nextDrawEndsAt(), drawPeriodSeconds * 2);

    uint256 _reserveAmount = 400e18;
    _mockReserves(address(prizePool), _reserveAmount);

    uint8 _phaseId = 0;
    rewardLib.setPhase(_phaseId, drawPeriodSeconds, uint64(_warpTimestamp), recipient);

    vm.warp(drawPeriodSeconds * 2 + auctionDuration);

    // A new auction has started but since the recorded start time
    // is before the start of the auction, reward should be 0
    assertEq(rewardLib.reward(0), 0);
  }

  function testPhase0RewardSetStartTime0AfterDrawPeriodEnd() public {
    uint256 _warpTimestamp = drawPeriodSeconds * 2 + (auctionDuration / 2);
    vm.warp(_warpTimestamp);

    assertEq(block.timestamp, _warpTimestamp);
    assertEq(prizePool.nextDrawEndsAt(), drawPeriodSeconds * 2);

    uint256 _reserveAmount = 400e18;
    _mockReserves(address(prizePool), _reserveAmount);

    uint8 _phaseId = 0;
    rewardLib.setPhase(_phaseId, 0, uint64(_warpTimestamp), recipient);

    vm.warp(drawPeriodSeconds * 2 + auctionDuration);

    // A new auction has started, since the recorded start time is 0,
    // we set it to the auction start time, so reward should be half the reserve amount
    assertEq(rewardLib.reward(0), _reserveAmount / 2);
  }
}
