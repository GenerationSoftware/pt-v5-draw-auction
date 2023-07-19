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

  function testAuctionDuration() public {
    assertEq(drawAuction.auctionDuration(), auctionDuration);
  }

  /* ============ completeAuction ============ */

  function testCompleteAuction() public {
    // Variables
    uint64 _rngCompletedAt = uint64(block.timestamp + 1);
    uint256 _randomNumber = 123;
    address _recipient = address(2);
    RngAuction.RngRequest memory _rngRequest = RngAuction.RngRequest(
      1, // rngRequestId
      uint32(block.number + 1), // lockBlock
      101, // sequenceId
      0 //rngRequestedAt
    );

    // Warp
    vm.warp(_rngCompletedAt + auctionDuration / 2); // reward portion will be 0.5

    // Mock Calls
    _mockRngAuction_getResults(rngAuction, _rngRequest, _rngCompletedAt);
    _mockRngAuction_currentSequenceId(rngAuction, 101);
    _mockRngAuction_randomNumber(rngAuction, _randomNumber);

    // Test
    drawAuction.completeDraw(_recipient);
    assertEq(drawAuction.lastRandomNumber(), _randomNumber);
    assertEq(drawAuction.afterDrawAuctionCounter(), 1);

    // Check phase
    Phase memory _drawPhase = drawAuction.getPhase();
    assertEq(UD2x18.unwrap(_drawPhase.rewardPortion), uint64(5e17)); // 0.5
    assertEq(_drawPhase.recipient, _recipient);
  }
}
