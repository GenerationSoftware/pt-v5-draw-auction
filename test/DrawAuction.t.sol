// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { ERC20Mock } from "openzeppelin/mocks/ERC20Mock.sol";

import { UD2x18, SD1x18, ConstructorParams, PrizePool, TieredLiquidityDistributor, TwabController } from "v5-prize-pool/PrizePool.sol";

import { DrawAuction } from "src/DrawAuction.sol";
import { AuctionLib } from "src/libraries/AuctionLib.sol";
import { Helpers, RNGInterface } from "test/helpers/Helpers.t.sol";

contract DrawAuctionTest is Helpers {
  /* ============ Events ============ */
  event AuctionRewardsDistributed(
    uint8[] phaseIds,
    address[] rewardRecipients,
    uint256[] rewardAmounts
  );

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

  /* ============ Reward ============ */
  /* ============ Half Time ============ */
  /* ============ Phase 0 ============ */
  function testPhase0RewardAtHalfTime() public {
    uint64 _warpTimestamp = drawPeriodSeconds + (auctionDuration / 2);
    vm.warp(_warpTimestamp);

    uint256 _reserveAmount = 200e18;
    _mockReserves(address(prizePool), _reserveAmount);

    AuctionLib.Phase memory _phase = _getPhase(0, uint64(0), _warpTimestamp, address(this));

    assertEq(drawAuction.reward(_phase), _reserveAmount / 2);
  }

  function testPhase0TriggeredRewardAtHalfTime() public {
    uint64 _warpTimestamp = drawPeriodSeconds + (auctionDuration / 2);
    vm.warp(_warpTimestamp);

    uint256 _reserveAmount = 200e18;
    _mockReserves(address(prizePool), _reserveAmount);

    _mockStartRNGRequest(address(rng), address(0), 0, uint32(1), uint32(block.number));
    drawAuction.startRNGRequest(recipient);

    vm.warp(drawPeriodSeconds + (auctionDuration));

    AuctionLib.Phase memory _phase = _getPhase(0, uint64(0), _warpTimestamp, address(this));

    assertEq(drawAuction.reward(_phase), _reserveAmount / 2);
  }

  /* ============ Phase 1 ============ */
  function testPhase1RewardAtHalfTimePhase0NotTriggered() public {
    uint64 _warpTimestamp = drawPeriodSeconds + (auctionDuration / 2);
    vm.warp(_warpTimestamp);

    AuctionLib.Phase memory _phase = _getPhase(0, uint64(0), _warpTimestamp, address(this));

    assertEq(drawAuction.reward(_phase), 0);
  }

  function testPhase1RewardAtHalfTimePhase0Triggered() public {
    uint64 _startRNGRequestTime = drawPeriodSeconds + (auctionDuration / 4); // drawPeriodSeconds + 45 minutes
    vm.warp(_startRNGRequestTime);

    _mockStartRNGRequest(address(rng), address(0), 0, uint32(1), uint32(block.number));
    drawAuction.startRNGRequest(recipient);

    vm.warp(drawPeriodSeconds + (auctionDuration / 2));

    uint256 _reserveAmount = 200e18;
    _mockReserves(address(prizePool), _reserveAmount);

    AuctionLib.Phase memory _phase = _getPhase(0, uint64(0), _startRNGRequestTime, address(this));

    assertEq(
      drawAuction.reward(_phase),
      _computeReward(
        uint64(block.timestamp - _startRNGRequestTime),
        _reserveAmount,
        auctionDuration
      )
    );
  }

  function testPhase1TriggeredRewardAtHalfTime() public {
    uint32 _requestId = uint32(1);
    uint32 _lockBlock = uint32(block.number);
    uint64 _startRNGRequestTime = drawPeriodSeconds + (auctionDuration / 4); // drawPeriodSeconds + 45 minutes

    uint256 _reserveAmount = 200e18;

    prizeToken.mint(address(prizePool), _reserveAmount * 125);
    prizePool.contributePrizeTokens(address(2), _reserveAmount * 125);

    vm.warp(_startRNGRequestTime);

    _mockStartRNGRequest(address(rng), address(0), 0, _requestId, _lockBlock);
    drawAuction.startRNGRequest(recipient);

    vm.warp(drawPeriodSeconds + (auctionDuration / 2));

    _mockReserves(address(prizePool), _reserveAmount);

    uint64 _phaseEndTime = uint64(block.timestamp);

    AuctionLib.Phase memory _phase = _getPhase(
      1,
      _startRNGRequestTime,
      _phaseEndTime,
      address(this)
    );

    assertEq(
      drawAuction.reward(_phase),
      _computeReward(_phaseEndTime - _startRNGRequestTime, _reserveAmount, auctionDuration)
    );

    _mockCompleteRNGRequest(address(rng), _requestId, randomNumber);

    drawAuction.completeRNGRequest(recipient);

    assertEq(prizeToken.balanceOf(recipient), _reserveAmount / 2);
  }

  /* ============ At or After auction ends ============ */

  function testRewardAtAuctionEnd() public {
    uint64 _warpTimestamp = drawPeriodSeconds + auctionDuration;
    vm.warp(_warpTimestamp);

    uint256 _reserveAmount = 200e18;
    _mockReserves(address(prizePool), _reserveAmount);

    AuctionLib.Phase memory _phase = _getPhase(0, uint64(0), _warpTimestamp, address(this));

    assertEq(drawAuction.reward(_phase), 200e18);
  }

  function testRewardAfterAuctionEnd() public {
    uint64 _warpTimestamp = drawPeriodSeconds + drawPeriodSeconds / 2;
    vm.warp(drawPeriodSeconds + drawPeriodSeconds / 2);

    uint256 _reserveAmount = 200e18;
    _mockReserves(address(prizePool), _reserveAmount);

    AuctionLib.Phase memory _phase = _getPhase(0, uint64(0), _warpTimestamp, address(this));

    assertEq(drawAuction.reward(_phase), _reserveAmount);
  }

  /* ============ _afterRNGComplete ============ */

  function testAfterRNGComplete() public {
    uint256 _reserveAmount = 200e18;

    prizeToken.mint(address(prizePool), _reserveAmount * 110);
    prizePool.contributePrizeTokens(address(2), _reserveAmount * 110);

    vm.warp(drawPeriodSeconds + auctionDuration / 2);

    uint32 _requestId = uint32(1);
    uint32 _lockBlock = uint32(block.number);

    _mockStartRNGRequest(address(rng), address(0), 0, _requestId, _lockBlock);

    drawAuction.startRNGRequest(recipient);

    vm.warp(drawPeriodSeconds + auctionDuration);

    _mockCompleteRNGRequest(address(rng), _requestId, randomNumber);

    drawAuction.completeRNGRequest(recipient);

    assertEq(prizeToken.balanceOf(recipient), _reserveAmount / 2);
  }

  function testAfterRNGCompleteDifferentRecipient() public {
    uint256 _reserveAmount = 200e18;

    prizeToken.mint(address(prizePool), _reserveAmount * 110);
    prizePool.contributePrizeTokens(address(2), _reserveAmount * 110);

    vm.warp(drawPeriodSeconds + auctionDuration / 2);

    uint32 _requestId = uint32(1);
    uint32 _lockBlock = uint32(block.number);

    _mockStartRNGRequest(address(rng), address(0), 0, _requestId, _lockBlock);

    address _secondRecipient = address(3);
    drawAuction.startRNGRequest(_secondRecipient);

    vm.warp(drawPeriodSeconds + auctionDuration);

    _mockCompleteRNGRequest(address(rng), _requestId, randomNumber);

    drawAuction.completeRNGRequest(recipient);

    assertEq(prizeToken.balanceOf(recipient), _reserveAmount / 4);
    assertEq(prizeToken.balanceOf(_secondRecipient), _reserveAmount / 4);
  }
}
