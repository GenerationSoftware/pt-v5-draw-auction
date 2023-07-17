// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { UD2x18 } from "prb-math/UD2x18.sol";

import { Phase } from "local-draw-auction/abstract/PhaseManager.sol";
import { RewardLib } from "local-draw-auction/libraries/RewardLib.sol";

// Note: Need to store the results from the library in a variable to be picked up by forge coverage
// See: https://github.com/foundry-rs/foundry/pull/3128#issuecomment-1241245086
contract RewardLibWrapper {
  function rewardPortion(
    uint64 _elapsedTime,
    uint64 _auctionDuration
  ) public pure returns (UD2x18) {
    UD2x18 result = RewardLib.rewardPortion(_elapsedTime, _auctionDuration);
    return result;
  }

  function rewards(
    Phase[] memory _phases,
    uint256 _reserve
  ) public pure returns (uint256[] memory) {
    uint256[] memory result = RewardLib.rewards(_phases, _reserve);
    return result;
  }

  function reward(Phase memory _phase, uint256 _reserve) public pure returns (uint256) {
    uint256 result = RewardLib.reward(_phase, _reserve);
    return result;
  }
}
