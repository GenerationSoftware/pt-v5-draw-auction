// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import { PhaseManagerHarness, Phase } from "test/harness/PhaseManagerHarness.sol";

contract PhaseManagerTest is Test {
  /* ============ Events ============ */
  event AuctionPhaseSet(
    uint8 indexed phaseId,
    uint64 startTime,
    uint64 endTime,
    address indexed recipient
  );

  /* ============ Variables ============ */
  PhaseManagerHarness public auction;

  uint8 public auctionPhases = 2;
  uint32 public auctionDuration = 3 hours;

  /* ============ SetUp ============ */
  function setUp() public {
    auction = new PhaseManagerHarness(auctionPhases);
  }

  /* ============ Getter Functions ============ */

  function testGetPhases() public {
    uint8 _firstPhaseId = 0;
    uint64 _startTime = uint64(block.timestamp);
    address _recipient = address(this);

    vm.warp(auctionDuration / 2);
    uint64 _endTime = uint64(block.timestamp);

    auction.setPhase(_firstPhaseId, _startTime, _endTime, _recipient);

    vm.warp(auctionDuration);
    uint8 _secondPhaseId = 1;
    uint64 _secondPhaseEndTime = uint64(block.timestamp);

    auction.setPhase(_secondPhaseId, _endTime, _secondPhaseEndTime, _recipient);

    Phase[] memory _phases = auction.getPhases();
    Phase memory _firstPhase = _phases[0];

    assertEq(_firstPhase.id, _firstPhaseId);
    assertEq(_firstPhase.startTime, _startTime);
    assertEq(_firstPhase.endTime, _endTime);
    assertEq(_firstPhase.recipient, _recipient);

    Phase memory _secondPhase = _phases[1];

    assertEq(_secondPhase.id, _secondPhaseId);
    assertEq(_secondPhase.startTime, _endTime);
    assertEq(_secondPhase.endTime, _secondPhaseEndTime);
    assertEq(_secondPhase.recipient, _recipient);
  }

  function testGetPhase() public {
    uint8 _phaseId = 0;
    uint64 _startTime = uint64(block.timestamp);
    address _recipient = address(this);

    vm.warp(auctionDuration / 2);
    uint64 _endTime = uint64(block.timestamp);

    auction.setPhase(_phaseId, _startTime, _endTime, _recipient);

    Phase memory _phase = auction.getPhase(_phaseId);

    assertEq(_phase.id, _phaseId);
    assertEq(_phase.startTime, _startTime);
    assertEq(_phase.endTime, _endTime);
    assertEq(_phase.recipient, _recipient);
  }

  /* ============ Setters ============ */

  function testSetPhase() public {
    uint8 _phaseId = 0;
    uint64 _startTime = uint64(block.timestamp);
    address _recipient = address(this);

    vm.warp(auctionDuration / 2);
    uint64 _endTime = uint64(block.timestamp);

    vm.expectEmit();
    emit AuctionPhaseSet(_phaseId, _startTime, _endTime, _recipient);

    Phase memory _phase = auction.setPhase(_phaseId, _startTime, _endTime, _recipient);

    assertEq(_phase.id, _phaseId);
    assertEq(_phase.startTime, _startTime);
    assertEq(_phase.endTime, _endTime);
    assertEq(_phase.recipient, _recipient);
  }
}
