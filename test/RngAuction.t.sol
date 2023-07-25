// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Helpers, RNGInterface, UD2x18, AuctionResults } from "test/helpers/Helpers.t.sol";

import { RngAuction } from "local-draw-auction/RngAuction.sol";

contract RngAuctionTest is Helpers {
  /* ============ Custom Errors ============ */

  /// @notice Thrown when the auction period is zero.
  error AuctionDurationZero();

  /// @notice Thrown when the sequence period is zero.
  error SequencePeriodZero();

  /**
   * @notice Thrown when the auction duration is greater than or equal to the sequence.
   * @param auctionDuration The auction duration in seconds
   * @param sequencePeriod The sequence period in seconds
   */
  error AuctionDurationGteSequencePeriod(uint64 auctionDuration, uint64 sequencePeriod);

  /// @notice Thrown when the RNG address passed to the setter function is zero address.
  error RngZeroAddress();

  /// @notice Thrown if an RNG request has already been made for the current sequence.
  error RngAlreadyStarted();

  /// @notice Thrown if the time elapsed since the start of the auction is greater than the auction duration.
  error AuctionExpired();

  /* ============ Events ============ */

  event AuctionCompleted(
    address indexed recipient,
    uint32 indexed sequenceId,
    uint64 elapsedTime,
    UD2x18 rewardFraction
  );

  event RngServiceSet(RNGInterface indexed rngService);

  event SetAuctionDuration(uint64 auctionDurationSeconds);

  /* ============ Variables ============ */

  RngAuction public rngAuction;
  RNGInterface public rng;

  uint64 _auctionDuration = 3 hours;
  uint64 _sequencePeriodSeconds = 1 days;
  uint64 _sequenceOffsetSeconds = 0;
  address _recipient = address(2);

  function setUp() public {
    vm.warp(0);

    rng = RNGInterface(makeAddr("rng"));
    vm.etch(address(rng), "rng");

    rngAuction = new RngAuction(
      rng,
      address(this),
      _sequencePeriodSeconds,
      _sequenceOffsetSeconds,
      _auctionDuration
    );
  }

  /* ============ startRngRequest() ============ */

  function testStartRngRequest() public {
    // Warp to halfway through auction
    vm.warp(_sequencePeriodSeconds + _auctionDuration / 2);

    // Variables
    uint32 _rngRequestId = 1;
    uint32 _lockBlock = uint32(block.number);

    // Mock calls
    _mockRngAuction_startRngRequest(rng, address(0), 0, _rngRequestId, _lockBlock);

    // Tests
    uint64 _requestedAt = uint64(block.timestamp);

    vm.expectEmit();
    emit AuctionCompleted(_recipient, 1, _auctionDuration / 2, UD2x18.wrap(uint64(5e17)));

    rngAuction.startRngRequest(_recipient);
    (AuctionResults memory _auctionResults, uint32 _sequenceId) = rngAuction.getAuctionResults();
    RngAuction.RngRequest memory _rngRequest = rngAuction.getRngRequest();

    assertEq(_sequenceId, 1);

    assertEq(_auctionResults.recipient, _recipient);
    assertEq(UD2x18.unwrap(_auctionResults.rewardFraction), 5e17);

    assertEq(_rngRequest.id, _rngRequestId);
    assertEq(_rngRequest.lockBlock, _lockBlock);
    assertEq(_rngRequest.sequenceId, 1);
    assertEq(_rngRequest.requestedAt, _requestedAt);
  }

  /* ============ isAuctionComplete() ============ */

  function testIsAuctionComplete_NotComplete() public {
    // Warp to halfway through auction
    vm.warp(_sequencePeriodSeconds + _auctionDuration / 2);

    // Test
    assertEq(rngAuction.isAuctionComplete(), false);
  }

  function testIsAuctionComplete_Completed() public {
    // Warp to halfway through auction
    vm.warp(_sequencePeriodSeconds + _auctionDuration / 2);

    // Complete auction
    _mockRngAuction_startRngRequest(rng, address(0), 0, 2, 1);
    rngAuction.startRngRequest(_recipient);

    // Test
    assertEq(rngAuction.isAuctionComplete(), true);
  }

  function testIsAuctionComplete_NextSequence() public {
    // Warp to halfway through auction
    vm.warp(_sequencePeriodSeconds + _auctionDuration / 2);

    // Complete auction
    _mockRngAuction_startRngRequest(rng, address(0), 0, 2, 1);
    rngAuction.startRngRequest(_recipient);

    // Warp to next sequence
    vm.warp(_sequencePeriodSeconds * 2);

    // Test
    assertEq(rngAuction.isAuctionComplete(), false);
  }

  /* ============ isAuctionOpen() ============ */

  function testIsAuctionOpen_IsOpen() public {
    // Warp to halfway through auction
    vm.warp(_sequencePeriodSeconds + _auctionDuration / 2);

    // Test
    assertEq(rngAuction.isAuctionOpen(), true);
  }

  function testIsAuctionOpen_AlreadyCompleted() public {
    // Warp to halfway through auction
    vm.warp(_sequencePeriodSeconds + _auctionDuration / 2);

    // Complete auction
    _mockRngAuction_startRngRequest(rng, address(0), 0, 2, 1);
    rngAuction.startRngRequest(_recipient);

    // Test
    assertEq(rngAuction.isAuctionOpen(), false);
  }

  function testIsAuctionOpen_Expired() public {
    // Warp to end of auction
    vm.warp(_sequencePeriodSeconds + _auctionDuration + 1);

    // Test
    assertEq(rngAuction.isAuctionOpen(), false);
  }

  /* ============ elapsedTime() ============ */

  function testElapsedTime_AtStart() public {
    // Warp to beginning of auction
    vm.warp(_sequencePeriodSeconds);

    // Test
    assertEq(rngAuction.elapsedTime(), 0);
  }

  function testElapsedTime_Halfway() public {
    // Warp to halfway point of auction
    vm.warp(_sequencePeriodSeconds + _auctionDuration / 2);

    // Test
    assertEq(rngAuction.elapsedTime(), _auctionDuration / 2);
  }

  function testElapsedTime_AtEnd() public {
    // Warp to end of auction
    vm.warp(_sequencePeriodSeconds + _auctionDuration);

    // Test
    assertEq(rngAuction.elapsedTime(), _auctionDuration);
  }

  function testElapsedTime_PastAuction() public {
    // Warp past auction
    vm.warp(_sequencePeriodSeconds + _auctionDuration + 1);

    // Test
    assertEq(rngAuction.elapsedTime(), _auctionDuration + 1);
  }

  /* ============ auctionDuration() ============ */

  function testAuctionDuration() public {
    assertEq(rngAuction.auctionDuration(), _auctionDuration);
  }

  /* ============ currentFractionalReward() ============ */

  function testCurrentRewardFraction_AtStart() public {
    // Warp to beginning of auction
    vm.warp(_sequencePeriodSeconds);

    // Test
    assertEq(UD2x18.unwrap(rngAuction.currentFractionalReward()), 0); // 0.0
  }

  function testCurrentRewardFraction_Halfway() public {
    // Warp to halfway point of auction
    vm.warp(_sequencePeriodSeconds + _auctionDuration / 2);

    // Test
    assertEq(UD2x18.unwrap(rngAuction.currentFractionalReward()), 5e17); // 0.5
  }

  function testCurrentRewardFraction_AtEnd() public {
    // Warp to end of auction
    vm.warp(_sequencePeriodSeconds + _auctionDuration);

    // Test
    assertEq(UD2x18.unwrap(rngAuction.currentFractionalReward()), 1e18); // 1.0
  }

  function testCurrentRewardFraction_PastAuction() public {
    // Warp past auction
    vm.warp(_sequencePeriodSeconds + _auctionDuration + _auctionDuration / 10);

    // Test
    assertEq(UD2x18.unwrap(rngAuction.currentFractionalReward()), 11e17); // 1.1
  }

  /* ============ getAuctionResults() ============ */

  function testGetAuctionResults() public {
    // Warp to halfway through auction
    vm.warp(_sequencePeriodSeconds + _auctionDuration / 2);

    // Variables
    uint32 _rngRequestId = 1;
    uint32 _lockBlock = uint32(block.number);

    // Start RNG Request
    _mockRngAuction_startRngRequest(rng, address(0), 0, _rngRequestId, _lockBlock);
    rngAuction.startRngRequest(_recipient);

    // Tests
    (AuctionResults memory _auctionResults, uint32 _sequenceId) = rngAuction.getAuctionResults();

    assertEq(_sequenceId, 1);
    assertEq(_auctionResults.recipient, _recipient);
    assertEq(UD2x18.unwrap(_auctionResults.rewardFraction), 5e17);
  }

  /* ============ currentSequenceId() ============ */

  function testCurrentSequence() public {
    vm.warp(0);
    assertEq(rngAuction.currentSequenceId(), 0);
    vm.warp(_sequencePeriodSeconds - 1);
    assertEq(rngAuction.currentSequenceId(), 0);

    vm.warp(_sequencePeriodSeconds);
    assertEq(rngAuction.currentSequenceId(), 1);
    vm.warp(_sequencePeriodSeconds * 2 - 1);
    assertEq(rngAuction.currentSequenceId(), 1);
  }

  function testCurrentSequence_WithOffset() public {
    uint64 _offset = 101;
    RngAuction offsetRngAuction = new RngAuction(
      rng,
      address(this),
      _sequencePeriodSeconds,
      _offset,
      _auctionDuration
    );

    vm.warp(_offset);
    assertEq(offsetRngAuction.currentSequenceId(), 0);
    vm.warp(_offset + _sequencePeriodSeconds - 1);
    assertEq(offsetRngAuction.currentSequenceId(), 0);

    vm.warp(_offset + _sequencePeriodSeconds);
    assertEq(offsetRngAuction.currentSequenceId(), 1);
    vm.warp(_offset + _sequencePeriodSeconds * 2 - 1);
    assertEq(offsetRngAuction.currentSequenceId(), 1);
  }

  function testFailCurrentSequence_BeforeOffset() public {
    uint64 _offset = 101;
    RngAuction offsetRngAuction = new RngAuction(
      rng,
      address(this),
      _sequencePeriodSeconds,
      _offset,
      _auctionDuration
    );

    vm.warp(_offset - 1);
    offsetRngAuction.currentSequenceId();
  }

  /* ============ isRngComplete() ============ */

  function testIsRngComplete_NotRequestedStartOfSequence() public {
    // Warp to start of auction
    vm.warp(_sequencePeriodSeconds);

    // Test
    assertEq(rngAuction.currentSequenceId(), 1);
    assertEq(rngAuction.isRngComplete(), false);
  }

  function testIsRngComplete_NotRequestedAfterAuction() public {
    // Warp to end of auction
    vm.warp(_sequencePeriodSeconds + _auctionDuration + 1);

    // Test
    assertEq(rngAuction.currentSequenceId(), 1);
    assertEq(rngAuction.isRngComplete(), false);
  }

  function testIsRngComplete_NotRequestedEndOfSequence() public {
    // Warp to end of auction
    vm.warp(_sequencePeriodSeconds * 2 - 1);

    // Test
    assertEq(rngAuction.currentSequenceId(), 1);
    assertEq(rngAuction.isRngComplete(), false);
  }

  /* ============ rngCompletedAt() ============ */

  function testRngCompletedAt() public {
    // Warp to halfway through auction
    vm.warp(_sequencePeriodSeconds + _auctionDuration / 2);

    // Variables
    uint32 _rngRequestId = 1;
    uint32 _lockBlock = uint32(block.number);
    uint64 _completedAt = uint64(block.timestamp + 1);

    // Start RNG Request
    _mockRngAuction_startRngRequest(rng, address(0), 0, _rngRequestId, _lockBlock);
    rngAuction.startRngRequest(_recipient);

    // Test
    _mockRngInterface_completedAt(rng, _rngRequestId, _completedAt);
    assertEq(rngAuction.rngCompletedAt(), _completedAt);
  }

  /* ============ getRngResults() ============ */

  function testGetRngResults() public {
    // Warp to halfway through auction
    vm.warp(_sequencePeriodSeconds + _auctionDuration / 2);

    // Variables
    uint32 _rngRequestId = 1;
    uint32 _lockBlock = uint32(block.number);
    uint256 _randomNumber = 12345;

    // Start RNG Request
    uint64 _requestedAt = uint64(block.timestamp);
    _mockRngAuction_startRngRequest(rng, address(0), 0, _rngRequestId, _lockBlock);
    rngAuction.startRngRequest(_recipient);

    // Mock calls
    uint64 _completedAt = _sequencePeriodSeconds + _auctionDuration / 2 + 100;
    vm.warp(_completedAt);
    _mockRngInterface_randomNumber(rng, _rngRequestId, _randomNumber);
    _mockRngInterface_completedAt(rng, _rngRequestId, _completedAt);

    // Test
    (
      RngAuction.RngRequest memory rngRequest_,
      uint256 randomNumber_,
      uint64 rngCompletedAt_
    ) = rngAuction.getRngResults();
    assertEq(rngRequest_.id, _rngRequestId);
    assertEq(rngRequest_.lockBlock, _lockBlock);
    assertEq(rngRequest_.sequenceId, 1);
    assertEq(rngRequest_.requestedAt, _requestedAt);
    assertEq(randomNumber_, _randomNumber);
    assertEq(rngCompletedAt_, _completedAt);
  }

  /* ============ getRngRequest() ============ */

  function testGetRngRequest() public {
    // Warp to halfway through auction
    vm.warp(_sequencePeriodSeconds + _auctionDuration / 2);

    // Variables
    uint32 _rngRequestId = 1;
    uint32 _lockBlock = uint32(block.number);

    // Start RNG Request
    uint64 _requestedAt = uint64(block.timestamp);
    _mockRngAuction_startRngRequest(rng, address(0), 0, _rngRequestId, _lockBlock);
    rngAuction.startRngRequest(_recipient);

    // Test
    RngAuction.RngRequest memory _rngRequest = rngAuction.getRngRequest();
    assertEq(_rngRequest.id, _rngRequestId);
    assertEq(_rngRequest.lockBlock, _lockBlock);
    assertEq(_rngRequest.sequenceId, 1);
    assertEq(_rngRequest.requestedAt, _requestedAt);

    // Warp to next sequence period and test that nothing has changed
    vm.warp(_sequencePeriodSeconds * 2 + _auctionDuration / 2);
    assertEq(rngAuction.currentSequenceId(), 2);

    RngAuction.RngRequest memory _rngRequest2 = rngAuction.getRngRequest();
    assertEq(_rngRequest2.id, _rngRequestId);
    assertEq(_rngRequest2.lockBlock, _lockBlock);
    assertEq(_rngRequest2.sequenceId, 1);
    assertEq(_rngRequest2.requestedAt, _requestedAt);
  }

  /* ============ getRngService() ============ */

  function testGetRngService() public {
    assertEq(address(rngAuction.getRngService()), address(rng));
  }

  /* ============ getPendingRngService() ============ */

  function testGetPendingRngService() public {
    assertEq(address(rngAuction.getPendingRngService()), address(rng));
  }

  /* ============ getSequenceOffset() ============ */

  function testGetSequenceOffset() public {
    assertEq(rngAuction.getSequenceOffset(), _sequenceOffsetSeconds);
  }

  /* ============ getSequencePeriod() ============ */

  function testGetSequencePeriod() public {
    assertEq(rngAuction.getSequencePeriod(), _sequencePeriodSeconds);
  }

  /* ============ setRngService() ============ */

  function testSetRngService() public {
    // Warp to halfway through auction
    vm.warp(_sequencePeriodSeconds + _auctionDuration / 2);

    RNGInterface _newRng = RNGInterface(address(123));

    vm.expectEmit();
    emit RngServiceSet(_newRng);
    rngAuction.setRngService(_newRng);

    assertEq(address(rngAuction.getRngService()), address(rng));
    assertEq(address(rngAuction.getPendingRngService()), address(_newRng));

    _mockRngAuction_startRngRequest(_newRng, address(0), 0, 1, 1);
    rngAuction.startRngRequest(_recipient);

    assertEq(address(rngAuction.getRngService()), address(_newRng));
    assertEq(address(rngAuction.getPendingRngService()), address(_newRng));
  }

  function testSetRngService_ZeroAddress() public {
    RNGInterface _newRng = RNGInterface(address(0));
    vm.expectRevert(abi.encodeWithSelector(RngZeroAddress.selector));
    rngAuction.setRngService(_newRng);
  }

  function testFailSetRngService_NotOwner() public {
    RNGInterface _newRng = RNGInterface(address(0));
    vm.startPrank(address(123));
    rngAuction.setRngService(_newRng);
    vm.stopPrank();
  }

  /* ============ setAuctionDuration() ============ */

  function testSetAuctionDuration() public {
    uint64 _newAuctionDuration = 2 hours;
    assertNotEq(_newAuctionDuration, _auctionDuration);

    vm.expectEmit();
    emit SetAuctionDuration(_newAuctionDuration);
    rngAuction.setAuctionDuration(_newAuctionDuration);

    assertEq(rngAuction.auctionDuration(), _newAuctionDuration);
  }

  function testSetAuctionDuration_Zero() public {
    uint64 _newAuctionDuration = 0;
    vm.expectRevert(abi.encodeWithSelector(AuctionDurationZero.selector));
    rngAuction.setAuctionDuration(_newAuctionDuration);
  }

  function testSetAuctionDuration_TooLong() public {
    uint64 _newAuctionDuration = _sequencePeriodSeconds;
    vm.expectRevert(
      abi.encodeWithSelector(
        AuctionDurationGteSequencePeriod.selector,
        _newAuctionDuration,
        _sequencePeriodSeconds
      )
    );
    rngAuction.setAuctionDuration(_newAuctionDuration);
  }

  function testFailSetAuctionDuration_NotOwner() public {
    vm.startPrank(address(123));
    rngAuction.setAuctionDuration(2 hours);
    vm.stopPrank();
  }
}
