// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { TwoStepsAuction, RNGInterface } from "src/auctions/TwoStepsAuction.sol";

contract TwoStepsAuctionHarness is TwoStepsAuction {
  constructor(
    RNGInterface rng_,
    uint32 rngTimeout_,
    uint8 _auctionPhases,
    uint32 auctionDuration_,
    address _owner
  ) TwoStepsAuction(rng_, rngTimeout_, _auctionPhases, auctionDuration_, _owner) {}

  function afterRNGStart(address _rewardRecipient) external {
    _afterRNGStart(_rewardRecipient);
  }

  function afterRNGComplete(uint256 _randomNumber, address _rewardRecipient) external {
    _afterRNGComplete(_randomNumber, _rewardRecipient);
  }
}
