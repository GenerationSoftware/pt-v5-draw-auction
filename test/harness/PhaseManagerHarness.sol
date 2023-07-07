// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { PhaseManager, Phase } from "src/abstract/PhaseManager.sol";

contract PhaseManagerHarness is PhaseManager {
  constructor(uint8 _auctionPhases) PhaseManager(_auctionPhases) {}

  function setPhase(
    uint8 _phaseId,
    uint64 _startTime,
    uint64 _endTime,
    address _recipient
  ) external returns (Phase memory) {
    return _setPhase(_phaseId, _startTime, _endTime, _recipient);
  }
}
