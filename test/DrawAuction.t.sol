// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { DrawAuctionHarness } from "test/harness/DrawAuctionHarness.sol";
import { Helpers, RNGInterface, UD2x18, AuctionResults } from "test/helpers/Helpers.t.sol";

import { StartRngAuction } from "local-draw-auction/StartRngAuction.sol";

contract DrawAuctionTest is Helpers {
  /* ============ Errors ============ */

  /// @notice Thrown if the auction period is zero.
  error AuctionDurationZero();

  /// @notice Thrown if the StartRngAuction address is the zero address.
  error StartRngAuctionZeroAddress();

  /// @notice Thrown if the current draw auction has already been completed.
  error DrawAlreadyCompleted();

  /// @notice Thrown if the current draw auction has expired.
  error DrawAuctionExpired();

  /// @notice Thrown if the RNG request is not complete for the current sequence.
  error RngNotCompleted();

  /* ============ Events ============ */

  event AuctionCompleted(
    address indexed recipient,
    uint32 indexed sequenceId,
    uint64 elapsedTime,
    UD2x18 rewardFraction
  );

  /* ============ Variables ============ */

  DrawAuctionHarness public drawAuction;
  StartRngAuction public rngAuction;
  RNGInterface public rng;

  uint64 _auctionDuration = 4 hours;
  uint64 _auctionTargetTime = 2 hours;
  uint64 _rngCompletedAt = uint64(block.timestamp + 1);
  uint256 _randomNumber = 123;
  address _recipient = address(2);
  uint32 _currentSequenceId = 101;
  StartRngAuction.RngRequest _rngRequest =
    StartRngAuction.RngRequest(
      1, // rngRequestId
      uint32(block.number + 1), // lockBlock
      _currentSequenceId, // sequenceId
      0 //rngRequestedAt
    );

  function setUp() public {
    vm.warp(0);

    rngAuction = StartRngAuction(makeAddr("rngAuction"));
    vm.etch(address(rngAuction), "rngAuction");

    rng = RNGInterface(makeAddr("rng"));
    vm.etch(address(rng), "rng");

    drawAuction = new DrawAuctionHarness(rngAuction, _auctionDuration, _auctionTargetTime);
  }

  /* ============ rngAuction() ============ */

  function testStartRngAuction() public {
    assertEq(address(drawAuction.rngAuction()), address(rngAuction));
  }

  /* ============ completeDraw() ============ */

  function testCompleteDraw() public {
    // Warp
    vm.warp(_rngCompletedAt + _auctionDuration); // reward fraction will be 1

    // Mock Calls
    _mockStartRngAuction_isRngComplete(rngAuction, true);
    _mockStartRngAuction_currentSequenceId(rngAuction, _currentSequenceId);
    _mockStartRngAuction_getRngResults(rngAuction, _rngRequest, _randomNumber, _rngCompletedAt);

    // Test
    drawAuction.completeDraw(_recipient);
    assertEq(drawAuction.lastRandomNumber(), _randomNumber);
    assertEq(drawAuction.afterDrawAuctionCounter(), 1);

    // Check results
    (AuctionResults memory _auctionResults, uint32 _sequenceId) = drawAuction.getAuctionResults();
    assertEq(_sequenceId, _currentSequenceId);
    assertEq(UD2x18.unwrap(_auctionResults.rewardFraction), uint64(1e18)); // 1
    assertEq(_auctionResults.recipient, _recipient);
  }

  function testCompleteDraw_EmitsEvent() public {
    // Warp
    vm.warp(_rngCompletedAt + _auctionDuration); // reward fraction will be 1

    // Mock Calls
    _mockStartRngAuction_isRngComplete(rngAuction, true);
    _mockStartRngAuction_currentSequenceId(rngAuction, _currentSequenceId);
    _mockStartRngAuction_getRngResults(rngAuction, _rngRequest, _randomNumber, _rngCompletedAt);

    // Test
    vm.expectEmit();
    emit AuctionCompleted(
      _recipient,
      _currentSequenceId,
      _auctionDuration,
      UD2x18.wrap(uint64(1e18))
    );
    drawAuction.completeDraw(_recipient);
  }

  function testCompleteDraw_RequiresAuctionNotCompleted() public {
    vm.warp(_rngCompletedAt + _auctionDuration / 2);

    // Complete draw once
    _mockStartRngAuction_isRngComplete(rngAuction, true);
    _mockStartRngAuction_currentSequenceId(rngAuction, _currentSequenceId);
    _mockStartRngAuction_getRngResults(rngAuction, _rngRequest, _randomNumber, _rngCompletedAt);
    drawAuction.completeDraw(_recipient);

    // Try to complete again
    _mockStartRngAuction_isRngComplete(rngAuction, true);
    _mockStartRngAuction_currentSequenceId(rngAuction, _currentSequenceId);
    _mockStartRngAuction_getRngResults(rngAuction, _rngRequest, _randomNumber, _rngCompletedAt);

    vm.expectRevert(abi.encodeWithSelector(DrawAlreadyCompleted.selector));
    drawAuction.completeDraw(_recipient);
  }

  function testCompleteDraw_RequiresRngCompleted() public {
    // Mock Calls
    _mockStartRngAuction_isRngComplete(rngAuction, false);

    // Test
    vm.expectRevert(abi.encodeWithSelector(RngNotCompleted.selector));
    drawAuction.completeDraw(address(this));
  }

  function testCompleteDraw_RequiresAuctionNotExpired() public {
    // Warp to after auction duration
    vm.warp(_rngCompletedAt + _auctionDuration + 1);

    // Mock calls
    _mockStartRngAuction_isRngComplete(rngAuction, true);
    _mockStartRngAuction_currentSequenceId(rngAuction, _currentSequenceId);
    _mockStartRngAuction_getRngResults(rngAuction, _rngRequest, _randomNumber, _rngCompletedAt);

    // Test
    vm.expectRevert(abi.encodeWithSelector(DrawAuctionExpired.selector));
    drawAuction.completeDraw(_recipient);
  }

  function testCompleteDraw_TwoSequences() public {
    // Warp to halfway between target time and end so that the price will be above zero
    vm.warp(_rngCompletedAt + _auctionTargetTime + (_auctionDuration - _auctionTargetTime) / 2);

    // Mock calls
    _mockStartRngAuction_isRngComplete(rngAuction, true);
    _mockStartRngAuction_currentSequenceId(rngAuction, _currentSequenceId);
    _mockStartRngAuction_getRngResults(rngAuction, _rngRequest, _randomNumber, _rngCompletedAt);

    // Test
    drawAuction.completeDraw(_recipient);
    (AuctionResults memory _auctionResults0, uint32 _sequenceId0) = drawAuction.getAuctionResults();
    assertEq(_sequenceId0, _currentSequenceId);
    assertGt(UD2x18.unwrap(_auctionResults0.rewardFraction), uint64(0)); // greater than zero
    assertLt(UD2x18.unwrap(_auctionResults0.rewardFraction), uint64(1e18)); // less than one
    assertEq(_auctionResults0.recipient, _recipient);

    // Warp to target time of next auction
    vm.warp(_rngCompletedAt + (_auctionDuration * 2) + _auctionTargetTime);

    // Mock calls for next sequence
    StartRngAuction.RngRequest memory _nextRngRequest = StartRngAuction.RngRequest(
      _rngRequest.id + 1,
      uint32(block.number),
      _currentSequenceId + 1,
      _rngRequest.requestedAt + _auctionDuration * 2
    );
    _mockStartRngAuction_isRngComplete(rngAuction, true);
    _mockStartRngAuction_currentSequenceId(rngAuction, _currentSequenceId + 1);
    _mockStartRngAuction_getRngResults(
      rngAuction,
      _nextRngRequest,
      _randomNumber + 1,
      _rngCompletedAt + _auctionDuration * 2
    );

    // Test
    drawAuction.completeDraw(address(this));
    (AuctionResults memory _auctionResults1, uint32 _sequenceId1) = drawAuction.getAuctionResults();
    assertEq(_sequenceId1, _currentSequenceId + 1);
    assertEq(
      UD2x18.unwrap(_auctionResults1.rewardFraction),
      UD2x18.unwrap(_auctionResults0.rewardFraction) // same as last sold fraction since we completed at the target time
    );
    assertEq(_auctionResults1.recipient, address(this));
  }

  /* ============ isAuctionComplete() ============ */

  function testIsAuctionComplete_NotComplete() public {
    // Complete draw
    vm.warp(_rngCompletedAt + _auctionDuration / 2);
    _mockStartRngAuction_isRngComplete(rngAuction, true);
    _mockStartRngAuction_currentSequenceId(rngAuction, _currentSequenceId);
    _mockStartRngAuction_getRngResults(rngAuction, _rngRequest, _randomNumber, _rngCompletedAt);
    drawAuction.completeDraw(_recipient);

    // Test
    _mockStartRngAuction_currentSequenceId(rngAuction, _currentSequenceId);
    assertEq(drawAuction.isAuctionComplete(), true);

    // Test false on next sequence
    _mockStartRngAuction_currentSequenceId(rngAuction, _currentSequenceId + 1);
    assertEq(drawAuction.isAuctionComplete(), false);
  }

  /* ============ isAuctionOpen() ============ */

  function testIsAuctionOpen_IsOpen() public {
    // Warp halfway through
    vm.warp(_rngCompletedAt + _auctionDuration / 2);
    _mockStartRngAuction_isRngComplete(rngAuction, true);
    _mockStartRngAuction_currentSequenceId(rngAuction, _currentSequenceId);
    _mockStartRngAuction_rngCompletedAt(rngAuction, _rngCompletedAt);

    // Test
    assertEq(drawAuction.isAuctionOpen(), true);
  }

  function testIsAuctionOpen_AlreadyCompleted() public {
    // Complete draw halfway through
    vm.warp(_rngCompletedAt + _auctionDuration / 2);
    _mockStartRngAuction_isRngComplete(rngAuction, true);
    _mockStartRngAuction_currentSequenceId(rngAuction, _currentSequenceId);
    _mockStartRngAuction_getRngResults(rngAuction, _rngRequest, _randomNumber, _rngCompletedAt);
    drawAuction.completeDraw(_recipient);

    // Mock calls
    _mockStartRngAuction_isRngComplete(rngAuction, true);
    _mockStartRngAuction_currentSequenceId(rngAuction, _currentSequenceId);
    _mockStartRngAuction_rngCompletedAt(rngAuction, _rngCompletedAt);

    // Test
    assertEq(drawAuction.isAuctionOpen(), false);
  }

  function testIsAuctionOpen_Expired() public {
    // Warp halfway through
    vm.warp(_rngCompletedAt + _auctionDuration + 1);
    _mockStartRngAuction_isRngComplete(rngAuction, true);
    _mockStartRngAuction_currentSequenceId(rngAuction, _currentSequenceId);
    _mockStartRngAuction_rngCompletedAt(rngAuction, _rngCompletedAt);

    // Test
    assertEq(drawAuction.isAuctionOpen(), false);
  }

  function testIsAuctionOpen_RngNotCompleted() public {
    _mockStartRngAuction_isRngComplete(rngAuction, false);

    // Test
    assertEq(drawAuction.isAuctionOpen(), false);
  }

  /* ============ elapsedTime() ============ */

  function testElapsedTime_AtStart() public {
    // Warp to beginning of auction
    vm.warp(_rngCompletedAt);
    _mockStartRngAuction_rngCompletedAt(rngAuction, _rngCompletedAt);

    // Test
    assertEq(drawAuction.elapsedTime(), 0);
  }

  function testElapsedTime_Halfway() public {
    // Warp to halfway point of auction
    vm.warp(_rngCompletedAt + _auctionDuration / 2);
    _mockStartRngAuction_rngCompletedAt(rngAuction, _rngCompletedAt);

    // Test
    assertEq(drawAuction.elapsedTime(), _auctionDuration / 2);
  }

  function testElapsedTime_AtEnd() public {
    // Warp to end of auction
    vm.warp(_rngCompletedAt + _auctionDuration);
    _mockStartRngAuction_rngCompletedAt(rngAuction, _rngCompletedAt);

    // Test
    assertEq(drawAuction.elapsedTime(), _auctionDuration);
  }

  function testElapsedTime_PastAuction() public {
    // Warp past auction
    vm.warp(_rngCompletedAt + _auctionDuration + 1);
    _mockStartRngAuction_rngCompletedAt(rngAuction, _rngCompletedAt);

    // Test
    assertEq(drawAuction.elapsedTime(), _auctionDuration + 1);
  }

  /* ============ auctionDuration() ============ */

  function testAuctionDuration() public {
    assertEq(drawAuction.auctionDuration(), _auctionDuration);
  }

  /* ============ currentFractionalReward() ============ */

  function testCurrentRewardFraction_AtStart() public {
    // Warp to beginning of auction
    vm.warp(_rngCompletedAt);
    _mockStartRngAuction_rngCompletedAt(rngAuction, _rngCompletedAt);

    // Test
    assertEq(UD2x18.unwrap(drawAuction.currentFractionalReward()), 0); // 0.0
  }

  function testCurrentRewardFraction_AtTargetTime() public {
    // Warp to halfway point of auction
    vm.warp(_rngCompletedAt + _auctionTargetTime);
    _mockStartRngAuction_rngCompletedAt(rngAuction, _rngCompletedAt);

    // Test
    (AuctionResults memory _lastResults, ) = drawAuction.getAuctionResults();
    assertEq(
      UD2x18.unwrap(drawAuction.currentFractionalReward()),
      UD2x18.unwrap(_lastResults.rewardFraction)
    ); // equal to last reward fraction
  }

  function testCurrentRewardFraction_AtEnd() public {
    // Warp to end of auction
    vm.warp(_rngCompletedAt + _auctionDuration);
    _mockStartRngAuction_rngCompletedAt(rngAuction, _rngCompletedAt);

    // Test
    assertEq(UD2x18.unwrap(drawAuction.currentFractionalReward()), 1e18); // 1.0
  }

  function testCurrentRewardFraction_PastAuction() public {
    // Warp past auction
    vm.warp(_rngCompletedAt + _auctionDuration + _auctionDuration / 10);
    _mockStartRngAuction_rngCompletedAt(rngAuction, _rngCompletedAt);

    // Test
    assertGe(UD2x18.unwrap(drawAuction.currentFractionalReward()), 1e18); // >= 1.0
  }

  /* ============ currentRewardAmount() ============ */

  function testCurrentRewardAmount_AtStart() public {
    // Warp to beginning of auction
    vm.warp(_rngCompletedAt);
    _mockStartRngAuction_rngCompletedAt(rngAuction, _rngCompletedAt);
    AuctionResults memory _auctionResults = AuctionResults(address(this), UD2x18.wrap(0.5e18)); // 0.5 reward for rng auction
    _mockIAuction_getAuctionResults(rngAuction, _auctionResults, 1);

    // Test
    assertEq(drawAuction.currentRewardAmount(2e18), 0); // none
  }

  function testCurrentRewardAmount_AtEnd() public {
    // Warp to end of auction
    vm.warp(_rngCompletedAt + _auctionDuration);
    _mockStartRngAuction_rngCompletedAt(rngAuction, _rngCompletedAt);
    AuctionResults memory _auctionResults = AuctionResults(address(this), UD2x18.wrap(0.5e18)); // 0.5 reward for rng auction
    _mockIAuction_getAuctionResults(rngAuction, _auctionResults, 1);

    // Test
    assertEq(drawAuction.currentRewardAmount(2e18), 1e18); // full - rngAuction reward
  }

  /* ============ getAuctionResults() ============ */

  function testGetAuctionResults() public {
    // Complete draw at end
    vm.warp(_rngCompletedAt + _auctionDuration);
    _mockStartRngAuction_isRngComplete(rngAuction, true);
    _mockStartRngAuction_currentSequenceId(rngAuction, _currentSequenceId);
    _mockStartRngAuction_getRngResults(rngAuction, _rngRequest, _randomNumber, _rngCompletedAt);
    drawAuction.completeDraw(_recipient);

    // Tests
    (AuctionResults memory _auctionResults, uint32 _sequenceId) = drawAuction.getAuctionResults();

    assertEq(_sequenceId, _currentSequenceId);
    assertEq(_auctionResults.recipient, _recipient);
    assertEq(UD2x18.unwrap(_auctionResults.rewardFraction), 1e18);
  }
}
