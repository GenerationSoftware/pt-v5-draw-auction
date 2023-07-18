// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { DrawAuctionHarness } from "test/harness/DrawAuctionHarness.sol";
import { Helpers, RNGInterface, UD2x18, Phase } from "test/helpers/Helpers.t.sol";

import { RngAuction } from "local-draw-auction/RngAuction.sol";

contract DrawAuctionTest is Helpers {
  /* ============ Variables ============ */

  DrawAuctionHarness public drawAuction;
  RngAuction public rngAuction;
  RNGInterface public rng;

  uint64 public auctionDuration = 3 hours;

  address public recipient = address(this);

  function setUp() public {
    vm.warp(0);

    rngAuction = RngAuction(makeAddr("rngAuction"));
    vm.etch(address(rngAuction), "rngAuction");

    rng = RNGInterface(makeAddr("rng"));
    vm.etch(address(rng), "rng");

    drawAuction = new DrawAuctionHarness(rngAuction, auctionDuration);
  }

  /* ============ Getter Functions ============ */

  function testRngAuction() public {
    assertEq(address(drawAuction.rngAuction()), address(rngAuction));
  }

  function testAuctionDurationSeconds() public {
    assertEq(drawAuction.auctionDurationSeconds(), auctionDuration);
  }

  /* ============ completeDraw ============ */

  function testCompleteDraw() public {
    // Warp
    vm.warp(auctionDuration / 2); // reward portion will be 0.5

    // Variables
    uint32 _rngRequestId = 1;
    bool _rngCompleted = true;
    uint256 _randomNumber = 123;
    address _recipient = address(2);

    // Mock Calls
    _mockRngAuction_getRngRequestId(rngAuction, _rngRequestId);
    _mockRngAuction_isRngCompleted(rngAuction, _rngCompleted);
    _mockRngAuction_getRngService(rngAuction, rng);
    _mockRngInterface_completedAt(rng, _rngRequestId, 0);
    _mockRngInterface_randomNumber(rng, _rngRequestId, _randomNumber);

    // Test
    drawAuction.completeDraw(_recipient);
    assertEq(drawAuction.lastRandomNumber(), _randomNumber);
    assertEq(drawAuction.afterCompleteDrawCounter(), 1);

    // Check phase
    Phase memory _drawPhase = drawAuction.getPhase();
    assertEq(UD2x18.unwrap(_drawPhase.rewardPortion), uint64(5e17)); // 0.5
    assertEq(_drawPhase.recipient, _recipient);
  }
}
