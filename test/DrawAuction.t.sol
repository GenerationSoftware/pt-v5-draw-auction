// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { DrawAuctionHarness } from "test/harness/DrawAuctionHarness.sol";
import { Helpers, RNGInterface, UD2x18, Phase } from "test/helpers/Helpers.t.sol";

import { RNGAuction } from "local-draw-auction/RNGAuction.sol";

contract DrawAuctionTest is Helpers {
  /* ============ Variables ============ */

  DrawAuctionHarness public drawAuction;
  RNGAuction public rngAuction;
  RNGInterface public rng;

  uint64 public auctionDuration = 3 hours;
  uint8 public auctionPhases = 2;
  string public auctionName = "Draw Auction Test";

  address public recipient = address(this);

  function setUp() public {
    vm.warp(0);

    rngAuction = RNGAuction(makeAddr("rngAuction"));
    vm.etch(address(rngAuction), "rngAuction");

    rng = RNGInterface(makeAddr("rng"));
    vm.etch(address(rng), "rng");

    drawAuction = new DrawAuctionHarness(rngAuction, auctionDuration, auctionPhases, auctionName);
  }

  /* ============ Getter Functions ============ */

  function testRNGAuction() public {
    assertEq(address(drawAuction.rngAuction()), address(rngAuction));
  }

  function testAuctionDurationSeconds() public {
    assertEq(drawAuction.auctionDurationSeconds(), auctionDuration);
  }

  function testAuctionName() public {
    assertEq(drawAuction.auctionName(), auctionName);
  }

  /* ============ completeDraw ============ */

  function testCompleteDraw() public {
    // Warp
    vm.warp(auctionDuration / 2); // reward portion will be 0.5

    // Variables
    uint32 _rngRequestId = 1;
    bool _rngCompleted = true;
    Phase memory _rngPhaseMock = Phase(UD2x18.wrap(1), address(this));
    uint256 _randomNumber = 123;
    address _recipient = address(2);

    // Mock Calls
    _mockRNGAuction_getRNGRequestId(rngAuction, _rngRequestId);
    _mockRNGAuction_isRNGCompleted(rngAuction, _rngCompleted);
    _mockRNGAuction_getRNGService(rngAuction, rng);
    _mockRNGInterface_completedAt(rng, _rngRequestId, 0);
    _mockPhaseManager_getPhase(rngAuction, 0, _rngPhaseMock);
    _mockRNGInterface_randomNumber(rng, _rngRequestId, _randomNumber);

    // Test
    drawAuction.completeDraw(_recipient);
    assertEq(drawAuction.lastRandomNumber(), _randomNumber);
    assertEq(drawAuction.afterCompleteDrawCounter(), 1);

    // Check phases
    Phase memory _rngPhase = drawAuction.getPhase(0);
    Phase memory _drawPhase = drawAuction.getPhase(1);
    assertEq(UD2x18.unwrap(_rngPhase.rewardPortion), UD2x18.unwrap(_rngPhaseMock.rewardPortion));
    assertEq(_rngPhase.recipient, _rngPhaseMock.recipient);
    assertEq(UD2x18.unwrap(_drawPhase.rewardPortion), uint64(5e17)); // 0.5
    assertEq(_drawPhase.recipient, _recipient);
  }
}
