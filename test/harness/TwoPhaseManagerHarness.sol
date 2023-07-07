// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { IDrawAuction, TwoPhaseManager, RNGInterface } from "src/TwoPhaseManager.sol";

contract TwoPhaseManagerHarness is TwoPhaseManager {
  constructor(
    RNGInterface rng_,
    uint32 rngTimeout_,
    uint8 _auctionPhases,
    IDrawAuction drawAuction_,
    address _owner
  ) TwoPhaseManager(rng_, rngTimeout_, _auctionPhases, drawAuction_, _owner) {}

  function afterRNGStart(address _rewardRecipient) external {
    _afterRNGStart(_rewardRecipient);
  }

  function afterRNGComplete(uint256 _randomNumber, address _rewardRecipient) external {
    _afterRNGComplete(_randomNumber, _rewardRecipient);
  }
}
