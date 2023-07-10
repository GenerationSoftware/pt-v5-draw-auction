// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { IDrawAuction } from "draw-auction-local/interfaces/IDrawAuction.sol";
import { TwoPhaseManager, RNGInterface } from "draw-auction-local/TwoPhaseManager.sol";

contract TwoPhaseManagerHarness is TwoPhaseManager {
  constructor(
    RNGInterface rng_,
    uint32 rngTimeout_,
    IDrawAuction drawAuction_,
    address _owner
  ) TwoPhaseManager(rng_, rngTimeout_, drawAuction_, _owner) {}

  function afterRNGStart(address _rewardRecipient) external {
    _afterRNGStart(_rewardRecipient);
  }

  function afterRNGComplete(uint256 _randomNumber, address _rewardRecipient) external {
    _afterRNGComplete(_randomNumber, _rewardRecipient);
  }
}
