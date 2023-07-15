// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import { IDrawAuction } from "src/interfaces/IDrawAuction.sol";
import { DrawAuctionZeroAddress } from "src/TwoPhaseManager.sol";
import { TwoPhaseManagerHarness, RNGInterface } from "test/harness/TwoPhaseManagerHarness.sol";

contract TwoPhaseManagerTest is Test {
  /* ============ Events ============ */
  // event AuctionPhaseCompleted(uint256 indexed phaseId, address indexed caller);

  /* ============ Variables ============ */
  TwoPhaseManagerHarness public auction;
  RNGInterface public rng;
  IDrawAuction public drawAuction;

  uint32 public rngTimeout = 1 hours;
  uint32 public auctionDuration = 3 hours;

  /* ============ SetUp ============ */
  function setUp() public {
    drawAuction = IDrawAuction(makeAddr("drawAuction"));
    vm.etch(address(drawAuction), "drawAuction");
    rng = RNGInterface(address(1));
    auction = new TwoPhaseManagerHarness(rng, rngTimeout, drawAuction, address(this));
  }

  /* ============ Hooks ============ */

  function testAfterRNGStart() public {
    vm.expectEmit();
    // emit AuctionPhaseCompleted(0, address(this));

    auction.afterRNGStart(address(this));
  }

  function testAfterRNGComplete() public {
    vm.expectEmit();
    // emit AuctionPhaseCompleted(1, address(this));

    auction.afterRNGComplete(123456789, uint64(block.timestamp), address(this));
  }

  /* ============ Constructor Params ============ */

  function testPhaseManagerHas2Phases() public {
    assertEq(auction.getPhases().length, 2);
  }

  /* ============ Constructor Errors ============ */

  function testDrawAuctionZeroAddressError() public {
    vm.expectRevert(abi.encodeWithSelector(DrawAuctionZeroAddress.selector));
    new TwoPhaseManagerHarness(
      rng,
      rngTimeout,
      IDrawAuction(address(0)), // zero address
      address(this)
    );
  }

  /* ============ Getters ============ */

  function testGetDrawAuction() public {
    assertEq(address(auction.drawAuction()), address(drawAuction));
  }
}
