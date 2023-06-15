// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

import { UD2x18, SD1x18, IERC20, PrizePool, TieredLiquidityDistributor, TwabController } from "v5-prize-pool/PrizePool.sol";

import { DrawAuction } from "src/DrawAuction.sol";

contract DrawAuctionTest is Test {
  DrawAuction internal _drawAuction;
  PrizePool internal _prizePool;

  uint32 internal _auctionDuration = 3 hours;

  function setUp() public {
    _prizePool = new PrizePool(
      IERC20(address(0)),
      TwabController(address(0)),
      uint32(365),
      1 days,
      uint64(block.timestamp),
      uint8(2), // minimum number of tiers
      100,
      10,
      10,
      UD2x18.wrap(0.9e18), // claim threshold of 90%
      SD1x18.wrap(0.9e18) // alpha
    );

    _drawAuction = new DrawAuction(_prizePool, 86400, _auctionDuration);

    vm.warp(0);

    vm.mockCall(
      address(_prizePool),
      abi.encodeWithSelector(TieredLiquidityDistributor.reserve.selector),
      abi.encode(100e18)
    );

    vm.mockCall(
      address(_prizePool),
      abi.encodeWithSelector(PrizePool.reserveForNextDraw.selector),
      abi.encode(100e18)
    );

    vm.mockCall(
      address(_prizePool),
      abi.encodeWithSelector(PrizePool.nextDrawEndsAt.selector),
      abi.encode(1 days)
    );
  }

  function testRewardBeforeTime() public {
    assertEq(_drawAuction.reward(), 0);
  }

  function testRewardAtTime0() public {
    vm.warp(1 days);

    assertEq(_drawAuction.reward(), 0);
  }

  function testRewardAtHalfTime() public {
    vm.warp(1 days + _auctionDuration / 2);

    assertEq(_drawAuction.reward(), 100e18);
  }

  function testRewardAtFullTime() public {
    vm.warp(1 days + _auctionDuration);

    assertEq(_drawAuction.reward(), 200e18);
  }

  function testRewardAfterTime() public {
    vm.warp(2 days);

    assertEq(_drawAuction.reward(), 200e18);
  }
}
