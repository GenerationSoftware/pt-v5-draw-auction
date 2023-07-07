// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { ERC20Mock } from "openzeppelin/mocks/ERC20Mock.sol";

import { UD2x18, SD1x18, ConstructorParams, PrizePool, TieredLiquidityDistributor, TwabController } from "v5-prize-pool/PrizePool.sol";

import { DrawAuction } from "src/DrawAuction.sol";
import { OnlyPhaseManager } from "src/interfaces/IDrawAuction.sol";
import { Phase } from "src/abstract/PhaseManager.sol";
import { Helpers, RNGInterface } from "test/helpers/Helpers.t.sol";

contract DrawAuctionTest is Helpers {
  /* ============ Events ============ */
  event AuctionRewardsDistributed(
    Phase[] phases,
    uint256 randomNumber,
    uint256[] rewardAmounts
  );

  /* ============ Variables ============ */

  Phase[] public phases;

  DrawAuction public drawAuction;
  ERC20Mock public prizeToken;
  PrizePool public prizePool;
  RNGInterface public rng;

  uint32 public auctionDuration = 3 hours;
  uint32 public rngTimeOut = 1 hours;
  uint32 public drawPeriodSeconds = 1 days;
  // uint256 public randomNumber = 123456789;
  address public recipient = address(this);

  function setUp() public {
    vm.warp(0);

    prizeToken = new ERC20Mock();
    prizePool = PrizePool(makeAddr("prizePool"));
    vm.etch(address(prizePool), "prizePool");

    while(phases.length > 0) {
      phases.pop();
    }

    rng = RNGInterface(address(1));

    drawAuction = new DrawAuction(prizePool, address(this), auctionDuration);
  }

  /* ============ Getter Functions ============ */

  function testPrizePool() public {
    assertEq(address(drawAuction.prizePool()), address(prizePool));
  }

  function testPhaseManager() public {
    assertEq(address(drawAuction.phaseManager()), address(this));
  }

  /* ============ State Functions ============ */

  function testReward() public {
    uint64 _warpTimestamp = drawPeriodSeconds + (auctionDuration / 2);
    vm.warp(_warpTimestamp);

    Phase memory _phase = Phase({
      id: 0,
      startTime: 0,
      endTime: _warpTimestamp,
      recipient: address(this)
    });

    mockOpenDrawEndsAt(drawPeriodSeconds);
    mockReserve(20e18);

    assertEq(drawAuction.reward(_phase), 10e18);
  }

  /* ============ completeAuction ============ */

  function testCompleteAuction_notPhaseManager() public {
    vm.expectRevert(abi.encodeWithSelector(OnlyPhaseManager.selector));
    vm.prank(makeAddr("fake"));
    drawAuction.completeAuction(phases, 0x1234);
  }

  function testCompleteAuction_captureFullReserve() public {
    vm.warp(10 days);

    uint256 _reserveAmount = 200e18;

    // current time is at the end of the duration
    uint openDrawEndsAt = block.timestamp - auctionDuration;

    mockOpenDrawEndsAt(openDrawEndsAt);
    mockReserve(_reserveAmount);
    mockCloseDraw(0x1234);
    mockWithdrawReserve(recipient, _reserveAmount);

    phases.push(Phase({
      id: 0,
      startTime: uint64(openDrawEndsAt),
      endTime: uint64(openDrawEndsAt + auctionDuration),
      recipient: recipient
    }));

    uint256[] memory rewards = new uint256[](1);
    rewards[0] = _reserveAmount;

    vm.expectEmit();
    emit AuctionRewardsDistributed(
      phases, 0x1234, rewards
    );
    drawAuction.completeAuction(phases, 0x1234);
  }

  function testCompleteAuction_MultipleRecipients() public {
    vm.warp(10 days);

    uint256 _reserveAmount = 200e18;

    // current time is at the end of the duration
    uint openDrawEndsAt = block.timestamp - auctionDuration;

    mockOpenDrawEndsAt(openDrawEndsAt);
    mockReserve(_reserveAmount);
    mockCloseDraw(0x1234);
    mockWithdrawReserve(recipient, _reserveAmount);

    phases.push(Phase({
      id: 0,
      startTime: uint64(openDrawEndsAt),
      endTime: uint64(openDrawEndsAt + auctionDuration / 2),
      recipient: recipient
    }));

    phases.push(Phase({
      id: 1,
      startTime: uint64(openDrawEndsAt),
      endTime: uint64(openDrawEndsAt + auctionDuration / 2),
      recipient: recipient
    }));

    uint256[] memory rewards = new uint256[](2);
    rewards[0] = _reserveAmount / 2;
    rewards[1] = _reserveAmount / 2;

    vm.expectEmit();
    emit AuctionRewardsDistributed(
      phases, 0x1234, rewards
    );
    drawAuction.completeAuction(phases, 0x1234);
  }

  function mockOpenDrawEndsAt(uint time) public {
    vm.mockCall(address(prizePool), abi.encodeWithSelector(prizePool.openDrawEndsAt.selector), abi.encode(time));
  }

  function mockReserve(uint reserve) public {
    vm.mockCall(address(prizePool), abi.encodeWithSelector(prizePool.reserve.selector), abi.encode(reserve));
    vm.mockCall(address(prizePool), abi.encodeWithSelector(prizePool.reserveForOpenDraw.selector), abi.encode(0));
  }

  function mockCloseDraw(uint _randomNumber) public {
    vm.mockCall(address(prizePool), abi.encodeWithSelector(prizePool.closeDraw.selector, _randomNumber), abi.encode(1));
  }

  function mockWithdrawReserve(address _recipient, uint amount) public {
    vm.mockCall(address(prizePool), abi.encodeWithSelector(prizePool.withdrawReserve.selector, _recipient, amount), abi.encode());
  }
}
