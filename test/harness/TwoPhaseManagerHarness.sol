// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { IDrawAuction } from "src/interfaces/IDrawAuction.sol";
import { TwoPhaseManager, RNGInterface } from "src/TwoPhaseManager.sol";

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

  function afterRNGComplete(
    uint256 _randomNumber,
    uint64 _rngCompletedAt,
    address _rewardRecipient
  ) external {
    _afterRNGComplete(_randomNumber, _rngCompletedAt, _rewardRecipient);
  }
}
