// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/console2.sol";

import { Helpers, RNGInterface, UD2x18 } from "test/helpers/Helpers.t.sol";
import { ERC20Mintable } from "test/mocks/ERC20Mintable.sol";
import { AuctionResult } from "../src/interfaces/IAuction.sol";

import {
  RngAuction,
  RngAuctionResult,
  AuctionDurationZero,
  AuctionTargetTimeExceedsDuration,
  SequencePeriodZero,
  AuctionDurationGteSequencePeriod,
  RngZeroAddress,
  CannotStartNextSequence,
  AuctionTargetTimeZero,
  AuctionExpired
} from "../src/RngAuction.sol";

contract RngAuctionTest is Helpers {

  /* ============ Events ============ */

  event RngAuctionCompleted(
    address indexed recipient,
    uint32 indexed sequenceId,
    RNGInterface indexed rng,
    uint32 rngRequestId,
    uint64 elapsedTime,
    UD2x18 rewardFraction
  );

  event SetNextRngService(RNGInterface indexed rngService);

  event SetAuctionDuration(uint64 auctionDurationSeconds, uint64 auctionTargetTime);

  event Transfer(address indexed from, address indexed to, uint256 value);

  event Approval(address indexed owner, address indexed spender, uint256 value);

  /* ============ Variables ============ */

  RngAuction public rngAuction;
  RNGInterface public rng;
  ERC20Mintable public rngFeeToken;

  uint64 auctionDuration = 4 hours;
  uint64 auctionTargetTime = 2 hours;
  uint64 sequencePeriod = 1 days;
  uint64 sequenceOffset = 10 days;
  address _recipient = address(2);

  function setUp() public {
    vm.warp(0);

    rngFeeToken = new ERC20Mintable("RNG Fee Token", "RNGFT");

    rng = RNGInterface(makeAddr("rng"));
    vm.etch(address(rng), "rng");

    rngAuction = new RngAuction(
      rng,
      address(this),
      sequencePeriod,
      sequenceOffset,
      auctionDuration,
      auctionTargetTime
    );
  }

  function testConstructor() public {
    assertEq(address(rngAuction.getNextRngService()), address(rng));
    assertEq(rngAuction.sequencePeriod(), sequencePeriod);
    assertEq(rngAuction.sequenceOffset(), sequenceOffset);
    assertEq(rngAuction.auctionDuration(), auctionDuration);
    assertEq(rngAuction.auctionTargetTime(), auctionTargetTime);
  }

  /* ============ startRngRequest() ============ */

  function testStartRngRequest() public {
    // Warp to end of auction
    vm.warp(sequenceOffset + sequencePeriod + auctionDuration);

    // Variables
    uint32 _rngRequestId = 1;
    uint32 _lockBlock = uint32(block.number);

    // Mock calls
    _mockRngInterface_startRngRequest(rng, address(0), 0, _rngRequestId, _lockBlock);

    // Tests
    vm.expectEmit();
    emit RngAuctionCompleted(_recipient, 1, rng, 1, auctionDuration, UD2x18.wrap(uint64(1e18)));

    rngAuction.startRngRequest(_recipient);
    AuctionResult memory _auctionResults = rngAuction.getLastAuctionResult();

    assertEq(rngAuction.lastSequenceId(), 1);
    assertEq(_auctionResults.recipient, _recipient);
    assertEq(UD2x18.unwrap(_auctionResults.rewardFraction), 1e18);
  }

  function testStartRngRequest_AuctionExpired() public {
    // Warp to past end of auction
    vm.warp(sequenceOffset + sequencePeriod + auctionDuration + 1);

    // Variables
    uint32 _rngRequestId = 1;
    uint32 _lockBlock = uint32(block.number);

    // Mock calls
    _mockRngInterface_startRngRequest(rng, address(0), 0, _rngRequestId, _lockBlock);

    // Tests
    vm.expectRevert(abi.encodeWithSelector(AuctionExpired.selector));
    rngAuction.startRngRequest(_recipient);
  }

  function testStartRngRequest_CannotStartNextSequence() public {
    // Warp to end of auction
    vm.warp(sequenceOffset + sequencePeriod + auctionDuration);

    // Variables
    uint32 _rngRequestId = 1;
    uint32 _lockBlock = uint32(block.number);

    // Mock calls
    _mockRngInterface_startRngRequest(rng, address(0), 0, _rngRequestId, _lockBlock);

    // Start RNG request
    vm.expectEmit();
    emit RngAuctionCompleted(_recipient, 1, rng, 1, auctionDuration, UD2x18.wrap(uint64(1e18)));
    rngAuction.startRngRequest(_recipient);

    // Mock calls
    _mockRngInterface_startRngRequest(rng, address(0), 0, _rngRequestId, _lockBlock);

    // Try to complete again
    vm.expectRevert(abi.encodeWithSelector(CannotStartNextSequence.selector));
    rngAuction.startRngRequest(_recipient);
  }

  function testStartRngRequest_PayWithAllowance_NoAllowance() public {
    // Warp to end of auction
    vm.warp(sequenceOffset + sequencePeriod + auctionDuration);

    // Variables
    uint32 _rngRequestId = 1;
    uint32 _lockBlock = uint32(block.number);
    uint256 _fee = 2e18;

    // Mint fee to user
    rngFeeToken.mint(address(this), _fee);

    // Mock calls
    _mockRngInterface_startRngRequest(rng, address(rngFeeToken), _fee, _rngRequestId, _lockBlock);

    // Remove allowance
    rngFeeToken.approve(address(rngAuction), 0);

    // Tests
    vm.expectRevert("ERC20: insufficient allowance");
    rngAuction.startRngRequest(_recipient);
  }

  function testStartRngRequest_PayWithAllowance() public {
    // Warp to end of auction
    vm.warp(sequenceOffset + sequencePeriod + auctionDuration);

    // Variables
    uint32 _rngRequestId = 1;
    uint32 _lockBlock = uint32(block.number);
    uint256 _fee = 2e18;

    // Mock calls
    _mockRngInterface_startRngRequest(rng, address(rngFeeToken), _fee, _rngRequestId, _lockBlock);

    // Mint fee to user
    rngFeeToken.mint(address(this), _fee);

    // Set allowance
    rngFeeToken.approve(address(rngAuction), _fee);

    // Tests
    vm.expectEmit();
    emit Transfer(address(this), address(rngAuction), _fee);
    vm.expectEmit();
    emit Approval(address(rngAuction), address(rng), _fee);
    rngAuction.startRngRequest(_recipient);

    // Ensure rng can transfer from auction to service
    vm.startPrank(address(rng));
    vm.expectEmit();
    emit Transfer(address(rngAuction), address(rng), _fee);
    rngFeeToken.transferFrom(address(rngAuction), address(rng), _fee);
    vm.stopPrank();
  }

  function testStartRngRequest_PayBefore() public {
    // Warp to end of auction
    vm.warp(sequenceOffset + sequencePeriod + auctionDuration);

    // Variables
    uint32 _rngRequestId = 1;
    uint32 _lockBlock = uint32(block.number);
    uint256 _fee = 2e18;

    // Mock calls
    _mockRngInterface_startRngRequest(rng, address(rngFeeToken), _fee, _rngRequestId, _lockBlock);

    // Mint fee to user
    rngFeeToken.mint(address(this), _fee);

    // Remove allowance, but send funds directly instead
    rngFeeToken.approve(address(rngAuction), 0);
    rngFeeToken.transfer(address(rngAuction), _fee);

    // Tests
    vm.expectEmit();
    emit Approval(address(rngAuction), address(rng), _fee);
    rngAuction.startRngRequest(_recipient);

    // Ensure rng can transfer from auction to service
    vm.startPrank(address(rng));
    vm.expectEmit();
    emit Transfer(address(rngAuction), address(rng), _fee);
    rngFeeToken.transferFrom(address(rngAuction), address(rng), _fee);
    vm.stopPrank();
  }

  /* ============ canStartNextSequence() ============ */

  function testCanStartNextSequence_Halfway() public {
    // Warp to halfway through auction
    vm.warp(sequenceOffset + sequencePeriod + auctionDuration / 2);

    // Test
    assertEq(rngAuction.canStartNextSequence(), true, "can start next sequence");
  }

  function testCanStartNextSequence_Completed() public {
    // Warp to halfway through auction
    vm.warp(sequenceOffset + sequencePeriod + auctionDuration / 2);

    // Complete auction
    _mockRngInterface_startRngRequest(rng, address(0), 0, 2, 1);
    rngAuction.startRngRequest(_recipient);

    // Test
    assertEq(rngAuction.canStartNextSequence(), false, "cannot start next sequence");
  }

  function testCanStartNextSequence_NextSequence() public {
    // Warp to halfway through auction
    vm.warp(sequenceOffset + sequencePeriod + auctionDuration / 2);

    // Complete auction
    _mockRngInterface_startRngRequest(rng, address(0), 0, 2, 1);
    rngAuction.startRngRequest(_recipient);

    // Warp to next sequence
    vm.warp(sequenceOffset + sequencePeriod * 2);

    // Test
    assertEq(rngAuction.canStartNextSequence(), true, "can start next sequence");
  }

  function testComputeFractionalReward() public {
    assertEq(rngAuction.computeRewardFraction(0).unwrap(), 0);
    assertEq(rngAuction.computeRewardFraction(auctionDuration).unwrap(), 1e18);
  }

  /* ============ isAuctionOpen() ============ */

  function testIsAuctionOpen_IsOpen() public {
    // Warp to halfway through auction
    vm.warp(sequenceOffset + sequencePeriod + auctionDuration / 2);

    // Test
    assertEq(rngAuction.isAuctionOpen(), true);
  }

  function testIsAuctionOpen_AlreadyCompleted() public {
    // Warp to halfway through auction
    vm.warp(sequenceOffset + sequencePeriod + auctionDuration / 2);

    // Complete auction
    _mockRngInterface_startRngRequest(rng, address(0), 0, 2, 1);
    rngAuction.startRngRequest(_recipient);

    // Test
    assertEq(rngAuction.isAuctionOpen(), false);
  }

  function testIsAuctionOpen_Expired() public {
    // Warp to end of auction
    vm.warp(sequenceOffset + sequencePeriod + auctionDuration + 1);

    // Test
    assertEq(rngAuction.isAuctionOpen(), false);
  }

  /* ============ elapsedTime() ============ */

  function testAuctionElapsedTime_beforeStart() public {
    vm.warp(sequenceOffset - 1);
    assertEq(rngAuction.auctionElapsedTime(), 0);
  }

  function testAuctionElapsedTime_AtStart() public {
    // Warp to beginning of auction
    vm.warp(sequenceOffset + sequencePeriod);

    // Test
    assertEq(rngAuction.auctionElapsedTime(), 0);
  }

  function testAuctionElapsedTime_Halfway() public {
    // Warp to halfway point of auction
    vm.warp(sequenceOffset + sequencePeriod + auctionDuration / 2);

    // Test
    assertEq(rngAuction.auctionElapsedTime(), auctionDuration / 2);
  }

  function testAuctionElapsedTime_AtEnd() public {
    // Warp to end of auction
    vm.warp(sequenceOffset + sequencePeriod + auctionDuration);

    // Test
    assertEq(rngAuction.auctionElapsedTime(), auctionDuration);
  }

  function testAuctionElapsedTime_PastAuction() public {
    // Warp past auction
    vm.warp(sequenceOffset + sequencePeriod + auctionDuration + 1);

    // Test
    assertEq(rngAuction.auctionElapsedTime(), auctionDuration + 1);
  }

  /* ============ auctionDuration() ============ */

  function testAuctionDuration() public {
    assertEq(rngAuction.auctionDuration(), auctionDuration);
  }

  /* ============ currentFractionalReward() ============ */

  function testCurrentRewardFraction_AtStart() public {
    // Warp to beginning of auction
    vm.warp(sequenceOffset + sequencePeriod);

    // Test
    assertEq(UD2x18.unwrap(rngAuction.currentFractionalReward()), 0); // 0.0
  }

  function testCurrentRewardFraction_Halfway() public {
    // Warp to halfway point of auction
    vm.warp(sequenceOffset + sequencePeriod + auctionTargetTime);

    // Test
    AuctionResult memory _lastResults = rngAuction.getLastAuctionResult();
    assertEq(
      UD2x18.unwrap(rngAuction.currentFractionalReward()),
      UD2x18.unwrap(_lastResults.rewardFraction)
    ); // equal to last reward fraction
  }

  function testCurrentRewardFraction_AtEnd() public {
    // Warp to end of auction
    vm.warp(sequenceOffset + sequencePeriod + auctionDuration);

    // Test
    assertEq(UD2x18.unwrap(rngAuction.currentFractionalReward()), 1e18); // 1.0
  }

  function testCurrentRewardFraction_PastAuction() public {
    // Warp past auction
    vm.warp(sequenceOffset + sequencePeriod + auctionDuration + auctionDuration / 10);

    // Test
    assertGe(UD2x18.unwrap(rngAuction.currentFractionalReward()), 1e18); // >= 1.0
  }

  /* ============ getLastAuctionResult() ============ */

  function testGetAuctionResult() public {
    // Warp to end of auction
    vm.warp(sequenceOffset + sequencePeriod + auctionDuration);

    // Variables
    uint32 _rngRequestId = 1;
    uint32 _lockBlock = uint32(block.number);

    // Start RNG Request
    _mockRngInterface_startRngRequest(rng, address(0), 0, _rngRequestId, _lockBlock);
    rngAuction.startRngRequest(_recipient);

    // Tests
    AuctionResult memory _auctionResults = rngAuction.getLastAuctionResult();
    uint32 _sequenceId = rngAuction.openSequenceId();

    assertEq(_sequenceId, 1);
    assertEq(_auctionResults.recipient, _recipient);
    assertEq(UD2x18.unwrap(_auctionResults.rewardFraction), 1e18);
  }

  /* ============ openSequenceId() ============ */

  function testCurrentSequence() public {
    vm.warp(0);
    assertEq(rngAuction.openSequenceId(), 0);
    vm.warp(sequenceOffset + sequencePeriod - 1);
    assertEq(rngAuction.openSequenceId(), 0);

    vm.warp(sequenceOffset + sequencePeriod);
    assertEq(rngAuction.openSequenceId(), 1);
    vm.warp(sequenceOffset + sequencePeriod * 2 - 1);
    assertEq(rngAuction.openSequenceId(), 1);
  }

  function testCurrentSequence_WithOffset() public {
    uint64 _offset = 101;
    RngAuction offsetRngAuction = new RngAuction(
      rng,
      address(this),
      sequencePeriod,
      _offset,
      auctionDuration,
      auctionTargetTime
    );

    vm.warp(_offset);
    assertEq(offsetRngAuction.openSequenceId(), 0);
    vm.warp(_offset + sequencePeriod - 1);
    assertEq(offsetRngAuction.openSequenceId(), 0);

    vm.warp(_offset + sequencePeriod);
    assertEq(offsetRngAuction.openSequenceId(), 1);
    vm.warp(_offset + sequencePeriod * 2 - 1);
    assertEq(offsetRngAuction.openSequenceId(), 1);
  }

  function testOpenSequenceId_BeforeOffset() public {
    uint64 _offset = 101;
    RngAuction offsetRngAuction = new RngAuction(
      rng,
      address(this),
      sequencePeriod,
      _offset,
      auctionDuration,
      auctionTargetTime
    );

    vm.warp(_offset - 1);

    uint32 seqId = offsetRngAuction.openSequenceId();
    assertEq(seqId, 0, "sequence id is zero");
  }

  /* ============ isRngComplete() ============ */

  function testIsRngComplete_NotRequestedStartOfSequence() public {
    // Warp to start of auction
    vm.warp(sequenceOffset + sequencePeriod);

    // Test
    assertEq(rngAuction.openSequenceId(), 1);
    assertEq(rngAuction.isRngComplete(), false);
  }

  function testIsRngComplete_NotRequestedAfterAuction() public {
    // Warp to end of auction
    vm.warp(sequenceOffset + sequencePeriod + auctionDuration + 1);

    // Test
    assertEq(rngAuction.openSequenceId(), 1);
    assertEq(rngAuction.isRngComplete(), false);
  }

  function testIsRngComplete_NotRequestedEndOfSequence() public {
    // Warp to end of auction
    vm.warp(sequenceOffset + sequencePeriod * 2 - 1);

    // Test
    assertEq(rngAuction.openSequenceId(), 1);
    assertEq(rngAuction.isRngComplete(), false);
  }

  /* ============ rngCompletedAt() ============ */

  function testRngCompletedAt() public {
    // Warp to halfway through auction
    vm.warp(sequenceOffset + sequencePeriod + auctionDuration / 2);

    // Variables
    uint32 _rngRequestId = 1;
    uint32 _lockBlock = uint32(block.number);
    uint64 _completedAt = uint64(block.timestamp + 1);

    // Start RNG Request
    _mockRngInterface_startRngRequest(rng, address(0), 0, _rngRequestId, _lockBlock);
    rngAuction.startRngRequest(_recipient);

    // Test
    _mockRngInterface_randomNumber(rng, _rngRequestId, 0x1234);
    _mockRngInterface_completedAt(rng, _rngRequestId, _completedAt);

    (uint256 randomNumber, uint64 rngCompletedAt) = rngAuction.getRngResults();
    assertEq(randomNumber, 0x1234);
    assertEq(rngCompletedAt, _completedAt);
  }

  /* ============ getRngResults() ============ */

  function testGetRngResults() public {
    // Warp to halfway through auction
    vm.warp(sequenceOffset + sequencePeriod + auctionDuration / 2);

    // Variables
    uint32 _rngRequestId = 1;
    uint32 _lockBlock = uint32(block.number);
    uint256 _randomNumber = 12345;

    // Start RNG Request
    _mockRngInterface_startRngRequest(rng, address(0), 0, _rngRequestId, _lockBlock);
    rngAuction.startRngRequest(_recipient);

    // Mock calls
    uint64 _completedAt = sequencePeriod + auctionDuration / 2 + 100;
    vm.warp(_completedAt);
    _mockRngInterface_randomNumber(rng, _rngRequestId, _randomNumber);
    _mockRngInterface_completedAt(rng, _rngRequestId, _completedAt);

    // Test
    (
      uint256 randomNumber_,
      uint64 rngCompletedAt_
    ) = rngAuction.getRngResults();

    assertEq(rngAuction.lastSequenceId(), 1);
    assertEq(randomNumber_, _randomNumber);
    assertEq(rngCompletedAt_, _completedAt);
  }

  function testGetLastAuction() public {
    // Warp to halfway through auction
    vm.warp(sequenceOffset + sequencePeriod + auctionDuration / 2);

    // Variables
    uint32 _rngRequestId = 1;
    uint32 _lockBlock = uint32(block.number);

    // Start RNG Request
    _mockRngInterface_startRngRequest(rng, address(0), 0, _rngRequestId, _lockBlock);
    rngAuction.startRngRequest(_recipient);

    RngAuctionResult memory lastAuction = rngAuction.getLastAuction();
    assertEq(address(lastAuction.rng), address(rng));
    assertEq(address(lastAuction.recipient), address(_recipient));
    assertEq(lastAuction.sequenceId, 1);
  }

  /* ============ getRngRequest() ============ */

  function testGetRngRequest() public {
    // Warp to halfway through auction
    vm.warp(sequenceOffset + sequencePeriod + auctionDuration / 2);

    // Variables
    uint32 _rngRequestId = 1;
    uint32 _lockBlock = uint32(block.number);

    // Start RNG Request
    _mockRngInterface_startRngRequest(rng, address(0), 0, _rngRequestId, _lockBlock);
    rngAuction.startRngRequest(_recipient);

    // Test
    assertEq(rngAuction.lastSequenceId(), 1);

    // Warp to next sequence period and test that nothing has changed
    vm.warp(sequenceOffset + sequencePeriod * 2 + auctionDuration / 2);
    assertEq(rngAuction.openSequenceId(), 2);

    assertEq(rngAuction.lastSequenceId(), 1);
  }

  /* ============ getRngService() ============ */

  function testLastRngService() public {
    // not set after construction
    assertEq(address(rngAuction.getLastRngService()), address(0));
  }

  /* ============ getNextRngService() ============ */

  function testGetNextRngService() public {
    assertEq(address(rngAuction.getNextRngService()), address(rng));
  }

  /* ============ getSequenceOffset() ============ */

  function testGetSequenceOffset() public {
    assertEq(rngAuction.getSequenceOffset(), sequenceOffset);
  }

  /* ============ getSequencePeriod() ============ */

  function testGetSequencePeriod() public {
    assertEq(rngAuction.getSequencePeriod(), sequencePeriod);
  }

  /* ============ setNextRngService() ============ */

  function testSetRngService() public {
    // Warp to halfway through auction
    vm.warp(sequenceOffset + sequencePeriod + auctionDuration / 2);

    RNGInterface _newRng = RNGInterface(address(123));

    vm.expectEmit();
    emit SetNextRngService(_newRng);
    rngAuction.setNextRngService(_newRng);

    assertEq(address(rngAuction.getLastRngService()), address(0));
    assertEq(address(rngAuction.getNextRngService()), address(_newRng));

    _mockRngInterface_startRngRequest(_newRng, address(0), 0, 1, 1);
    rngAuction.startRngRequest(_recipient);

    assertEq(address(rngAuction.getLastRngService()), address(_newRng));
    assertEq(address(rngAuction.getNextRngService()), address(_newRng));
  }

  function testSetRngService_ZeroAddress() public {
    RNGInterface _newRng = RNGInterface(address(0));
    vm.expectRevert(abi.encodeWithSelector(RngZeroAddress.selector));
    rngAuction.setNextRngService(_newRng);
  }

  function testFailSetRngService_NotOwner() public {
    RNGInterface _newRng = RNGInterface(address(0));
    vm.startPrank(address(123));
    rngAuction.setNextRngService(_newRng);
    vm.stopPrank();
  }

}
