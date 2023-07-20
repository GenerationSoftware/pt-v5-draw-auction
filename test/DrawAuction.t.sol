// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { DrawAuctionHarness } from "test/harness/DrawAuctionHarness.sol";
import { Helpers, RNGInterface, UD2x18, AuctionResults } from "test/helpers/Helpers.t.sol";

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
    uint32 _currentSequenceId = 101;
    RngAuction.RngRequest memory _rngRequest = RngAuction.RngRequest(
      1, // rngRequestId
      uint32(block.number + 1), // lockBlock
      _currentSequenceId, // sequenceId
      0 //rngRequestedAt
    );

    // Warp
    vm.warp(_rngCompletedAt + auctionDuration / 2); // reward portion will be 0.5

    // Mock Calls
    _mockRngAuction_isRngComplete(rngAuction, true);
    _mockRngAuction_currentSequenceId(rngAuction, _currentSequenceId);
    _mockRngAuction_getRngResults(rngAuction, _rngRequest, _randomNumber, _rngCompletedAt);

    // Test
    drawAuction.completeDraw(_recipient);
    assertEq(drawAuction.lastRandomNumber(), _randomNumber);
    assertEq(drawAuction.afterDrawAuctionCounter(), 1);

    // Check results
    (AuctionResults memory _auctionResults, uint32 _sequenceId) = drawAuction.getAuctionResults();
    assertEq(_sequenceId, _currentSequenceId);
    assertEq(UD2x18.unwrap(_auctionResults.rewardPortion), uint64(5e17)); // 0.5
    assertEq(_auctionResults.recipient, _recipient);
  }
}
