// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import { UD2x18 } from "prb-math/UD2x18.sol";

import { PhaseManagerHarness, Phase } from "test/harness/PhaseManagerHarness.sol";

contract PhaseManagerTest is Test {
  /* ============ Events ============ */
  event AuctionPhaseSet(
    uint8 indexed phaseId,
    UD2x18 rewardPortion,
    address indexed recipient
  );

  /* ============ Variables ============ */
  PhaseManagerHarness public auction;

  uint8 public auctionPhases = 2;

  /* ============ SetUp ============ */
  function setUp() public {
    auction = new PhaseManagerHarness(auctionPhases);
  }

  /* ============ Getter Functions ============ */

  function testGetPhases() public {
    UD2x18 _portion0 = UD2x18(uint64(1));
    address _recipient0 = address(this);
    auction.setPhase(0, _portion0, _recipient0);

    UD2x18 _portion1 = UD2x18(uint64(2));
    address _recipient1 = address(1);
    auction.setPhase(1, _portion1, _recipient1);

    Phase[] memory _phases = auction.getPhases();
    assertEq(_phases.length, auctionPhases);

    Phase memory _phase0 = _phases[0];

    assertEq(_phase0.rewardPortion, _portion0);
    assertEq(_phase0.recipient, _recipient0);

    Phase memory _phase1 = _phases[1];

    assertEq(_phase1.rewardPortion, _portion1);
    assertEq(_phase1.recipient, _recipient1);
  }

  function testGetPhase() public {
    uint8 _phaseId = 0;
    UD2x18 _portion = UD2x18(uint64(1));
    address _recipient = address(this);

    auction.setPhase(_phaseId, _portion, _recipient);

    Phase memory _phase = auction.getPhase(_phaseId);

    assertEq(_phase.rewardPortion, _portion);
    assertEq(_phase.recipient, _recipient);
  }

  function testGetPhase_ZeroOnInit() public {
    Phase memory _phase = auction.getPhase(0);
    assertEq(_phase.rewardPortion, UD2x18(uint64(0)));
    assertEq(_phase.recipient, address(0));
  }

  /* ============ Setters ============ */

  function testSetPhase() public {
    uint8 _phaseId = 0;
    UD2x18 _rewardPortion = UD2x18(uint64(1));
    address _recipient = address(this);

    vm.expectEmit();
    emit AuctionPhaseSet(_phaseId, _rewardPortion, _recipient);

    Phase memory _phase = auction.setPhase(_phaseId, _rewardPortion, _recipient);

    assertEq(_phase.rewardPortion, _rewardPortion);
    assertEq(_phase.recipient, _recipient);
  }
}
