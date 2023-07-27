// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { UD2x18 } from "prb-math/UD2x18.sol";

import { AuctionResults } from "local-draw-auction/interfaces/IAuction.sol";
import { RewardLib } from "local-draw-auction/libraries/RewardLib.sol";

// Note: Need to store the results from the library in a variable to be picked up by forge coverage
// See: https://github.com/foundry-rs/foundry/pull/3128#issuecomment-1241245086
contract RewardLibWrapper {
  function fractionalReward(
    uint64 _elapsedTime,
    uint64 _auctionDuration,
    UD2x18 _targetTimeFraction,
    UD2x18 _targetRewardFraction
  ) public pure returns (UD2x18) {
    UD2x18 result = RewardLib.fractionalReward(
      _elapsedTime,
      _auctionDuration,
      _targetTimeFraction,
      _targetRewardFraction
    );
    return result;
  }

  function rewards(
    AuctionResults[] memory _auctionResults,
    uint256 _reserve
  ) public pure returns (uint256[] memory) {
    uint256[] memory result = RewardLib.rewards(_auctionResults, _reserve);
    return result;
  }

  function reward(
    AuctionResults memory _auctionResults,
    uint256 _reserve
  ) public pure returns (uint256) {
    uint256 result = RewardLib.reward(_auctionResults, _reserve);
    return result;
  }
}
