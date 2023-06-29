// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import { TwoStepsAuctionHarness, RNGInterface } from "test/harness/TwoStepsAuctionHarness.sol";

contract TwoStepsAuctionTest is Test {
  /* ============ Events ============ */
  event AuctionPhaseCompleted(uint256 indexed phaseId, address indexed caller);

  /* ============ Variables ============ */
  TwoStepsAuctionHarness public auction;
  RNGInterface public rng;

  uint32 public rngTimeout = 1 hours;
  uint8 public auctionPhases = 2;
  uint32 public auctionDuration = 3 hours;

  /* ============ SetUp ============ */
  function setUp() public {
    rng = RNGInterface(address(1));
    auction = new TwoStepsAuctionHarness(
      rng,
      rngTimeout,
      auctionPhases,
      auctionDuration,
      address(this)
    );
  }

  /* ============ Hooks ============ */

  function testAfterRNGStart() public {
    vm.expectEmit();
    emit AuctionPhaseCompleted(0, address(this));

    auction.afterRNGStart(address(this));
  }

  function testAfterRNGComplete() public {
    vm.expectEmit();
    emit AuctionPhaseCompleted(1, address(this));

    auction.afterRNGComplete(123456789, address(this));
  }
}
