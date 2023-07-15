// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { PhaseManager, Phase } from "src/abstract/PhaseManager.sol";
import { UD2x18 } from "prb-math/UD2x18.sol";

contract PhaseManagerHarness is PhaseManager {
  constructor(uint8 _auctionPhases) PhaseManager(_auctionPhases) {}

  function setPhase(
    uint8 _phaseId,
    UD2x18 _rewardPortion,
    address _recipient
  ) external returns (Phase memory) {
    return _setPhase(_phaseId, _rewardPortion, _recipient);
  }
}
