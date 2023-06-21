// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { ERC20Mock } from "openzeppelin/mocks/ERC20Mock.sol";

import { UD2x18, SD1x18, ConstructorParams, PrizePool, TieredLiquidityDistributor, TwabController } from "v5-prize-pool/PrizePool.sol";

import { DrawAuction } from "src/DrawAuction.sol";
import { Helpers, RNGInterface } from "./helpers/Helpers.t.sol";

contract DrawAuctionTest is Helpers {
  /* ============ Events ============ */
  event DrawAuctionCompleted(address indexed caller, uint256 rewardAmount);

  /* ============ Variables ============ */

  DrawAuction public drawAuction;
  ERC20Mock public prizeToken;
  PrizePool public prizePool;
  RNGInterface public rng;

  uint32 public auctionDuration = 3 hours;
  uint32 public rngTimeOut = 1 hours;
  uint32 public drawPeriodSeconds = 1 days;
  uint256 public randomNumber = 123456789;
  address public recipient = address(this);

  function setUp() public {
    vm.warp(0);

    prizeToken = new ERC20Mock();
    console2.log("drawPeriodSeconds", drawPeriodSeconds);

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

    rng = RNGInterface(address(1));

    drawAuction = new DrawAuction(rng, rngTimeOut, prizePool, 2, auctionDuration, address(this));

    prizePool.setDrawManager(address(drawAuction));
  }

  /* ============ Getter Functions ============ */

  function testAuctionDuration() public {
    assertEq(drawAuction.auctionDuration(), auctionDuration);
  }

  function testPrizePool() public {
    assertEq(address(drawAuction.prizePool()), address(prizePool));
  }

  /* ============ State Functions ============ */

  /* ============ reward ============ */

  function testRewardBeforeDrawEnds() public {
    assertEq(drawAuction.reward(0), 0);
    assertEq(drawAuction.reward(1), 0);
  }

  function testRewardAtDrawEnds() public {
    vm.warp(drawPeriodSeconds);

    assertEq(drawAuction.reward(0), 0);
    assertEq(drawAuction.reward(1), 0);
  }

  /* ============ Half Time ============ */
  /* ============ Phase 0 ============ */
  function testPhase0RewardAtHalfTime() public {
    vm.warp(drawPeriodSeconds + (auctionDuration / 2));

    uint256 _reserveAmount = 200e18;
    _mockReserves(address(prizePool), _reserveAmount);

    assertEq(drawAuction.reward(0), _reserveAmount / 2);
  }

  function testPhase0TriggeredRewardAtHalfTime() public {
    vm.warp(drawPeriodSeconds + (auctionDuration / 2));

    uint256 _reserveAmount = 200e18;
    _mockReserves(address(prizePool), _reserveAmount);

    _mockStartRNGRequest(address(rng), address(0), 0, uint32(1), uint32(block.number));
    drawAuction.startRNGRequest(recipient);

    vm.warp(drawPeriodSeconds + (auctionDuration));

    assertEq(drawAuction.reward(0), _reserveAmount / 2);
  }

  /* ============ Phase 1 ============ */
  function testPhase1RewardAtHalfTimePhase0NotTriggered() public {
    vm.warp(drawPeriodSeconds + (auctionDuration / 2));
    assertEq(drawAuction.reward(1), 0);
  }

  function testPhase1RewardAtHalfTimePhase0Triggered() public {
    uint256 _startRNGRequestTime = drawPeriodSeconds + (auctionDuration / 4); // drawPeriodSeconds + 45 minutes

    vm.warp(_startRNGRequestTime);

    _mockStartRNGRequest(address(rng), address(0), 0, uint32(1), uint32(block.number));
    drawAuction.startRNGRequest(recipient);

    vm.warp(drawPeriodSeconds + (auctionDuration / 2));

    uint256 _reserveAmount = 200e18;
    _mockReserves(address(prizePool), _reserveAmount);

    assertEq(
      drawAuction.reward(1),
      _computeReward(block.timestamp - _startRNGRequestTime, _reserveAmount, auctionDuration)
    );
  }

  function testPhase1TriggeredRewardAtHalfTime() public {
    uint32 _requestId = uint32(1);
    uint32 _lockBlock = uint32(block.number);
    uint256 _startRNGRequestTime = drawPeriodSeconds + (auctionDuration / 4); // drawPeriodSeconds + 45 minutes

    vm.warp(_startRNGRequestTime);

    _mockStartRNGRequest(address(rng), address(0), 0, _requestId, _lockBlock);
    drawAuction.startRNGRequest(recipient);

    vm.warp(drawPeriodSeconds + (auctionDuration / 2));

    uint256 _reserveAmount = 200e18;
    _mockReserves(address(prizePool), _reserveAmount);

    assertEq(
      drawAuction.reward(1),
      _computeReward(block.timestamp - _startRNGRequestTime, _reserveAmount, auctionDuration)
    );

    _mockCompleteRNGRequest(address(rng), _requestId, randomNumber);

    drawAuction.completeRNGRequest(recipient);
  }

  /* ============ At or Aftter auction ends ============ */

  function testRewardAtAuctionEnd() public {
    vm.warp(drawPeriodSeconds + auctionDuration);

    uint256 _reserveAmount = 200e18;
    _mockReserves(address(prizePool), _reserveAmount);

    assertEq(drawAuction.reward(0), 200e18);
  }

  function testRewardAfterAuctionEnd() public {
    vm.warp(drawPeriodSeconds + drawPeriodSeconds / 2);

    uint256 _reserveAmount = 200e18;
    _mockReserves(address(prizePool), _reserveAmount);

    assertEq(drawAuction.reward(0), _reserveAmount);
  }

  /* ============ _afterRNGComplete ============ */

  function testAfterRNGComplete() public {
    console2.log("accountedBalance before", prizePool.accountedBalance());
    uint256 _reserveAmount = 200e18;

    prizeToken.mint(address(prizePool), _reserveAmount * 2);
    prizePool.contributePrizeTokens(address(2), _reserveAmount * 2);

    console2.log("accountedBalance after", prizePool.accountedBalance());

    vm.warp(drawPeriodSeconds + auctionDuration);

    uint32 _requestId = uint32(1);
    uint32 _lockBlock = uint32(block.number);
    // uint256 _rewardAmount = drawAuction.reward(0);

    _mockStartRNGRequest(address(rng), address(0), 0, _requestId, _lockBlock);

    drawAuction.startRNGRequest(recipient);

    _mockCompleteRNGRequest(address(rng), _requestId, randomNumber);

    // vm.expectEmit();
    // emit DrawAuctionCompleted(address(this), _rewardAmount);

    drawAuction.completeRNGRequest(recipient);
  }
}
