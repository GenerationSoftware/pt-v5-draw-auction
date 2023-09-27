// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { UD2x18 } from "prb-math/UD2x18.sol";
import { UD60x18, convert } from "prb-math/UD60x18.sol";

import { AuctionResult } from "../interfaces/IAuction.sol";

/// @title RewardLib
/// @author G9 Software Inc.
/// @notice Library for calculating auction rewards.
/// @dev This library uses a parabolic fractional dutch auction (PFDA) to calculate rewards. For more details see https://dev.pooltogether.com/protocol/next/design/draw-auction#parabolic-fractional-dutch-auction-pfda
library RewardLib {
  /* ============ Internal Functions ============ */

  /**
   * @notice Calculates the fractional reward using a Parabolic Fractional Dutch Auction (PFDA)
   * given the elapsed time, auction time, and target sale parameters.
   * @param _elapsedTime The elapsed time since the start of the auction in seconds
   * @param _auctionDuration The auction duration in seconds
   * @param _targetTimeFraction The target sale time as a fraction of the total auction duration (0.0,1.0]
   * @param _targetRewardFraction The target fractional sale price
   * @return The reward fraction as a UD2x18 fraction
   */
  function fractionalReward(
    uint64 _elapsedTime,
    uint64 _auctionDuration,
    UD2x18 _targetTimeFraction,
    UD2x18 _targetRewardFraction
  ) internal pure returns (UD2x18) {
    UD60x18 x = convert(_elapsedTime).div(convert(_auctionDuration));
    UD60x18 t = UD60x18.wrap(_targetTimeFraction.unwrap());
    UD60x18 r = UD60x18.wrap(_targetRewardFraction.unwrap());
    UD60x18 rewardFraction;
    if (x.gt(t)) {
      UD60x18 tDelta = x.sub(t);
      UD60x18 oneMinusT = convert(1).sub(t);
      rewardFraction = r.add(
        convert(1).sub(r).mul(tDelta).mul(tDelta).div(oneMinusT).div(oneMinusT)
      );
    } else {
      UD60x18 tDelta = t.sub(x);
      rewardFraction = r.sub(r.mul(tDelta).mul(tDelta).div(t).div(t));
    }
    return UD2x18.wrap(uint64(rewardFraction.unwrap()));
  }

  /**
   * @notice Calculates rewards to distribute given the available reserve and completed
   * auction results.
   * @dev Each auction takes a fraction of the remaining reserve. This means that if the
   * reserve is equal to 100 and the first auction takes 50% and the second takes 50%, then
   * the first reward will be equal to 50 while the second will be 25.
   * @param _auctionResults Auction results to get rewards for
   * @param _reserve Reserve available for the rewards
   * @return Rewards in the same order as the auction results they correspond to
   */
  function rewards(
    AuctionResult[] memory _auctionResults,
    uint256 _reserve
  ) internal pure returns (uint256[] memory) {
    uint256 remainingReserve = _reserve;
    uint256 _auctionResultsLength = _auctionResults.length;
    uint256[] memory _rewards = new uint256[](_auctionResultsLength);
    for (uint256 i; i < _auctionResultsLength; i++) {
      _rewards[i] = reward(_auctionResults[i], remainingReserve);
      remainingReserve = remainingReserve - _rewards[i];
    }
    return _rewards;
  }

  /**
   * @notice Calculates the reward for the given auction result and available reserve.
   * @dev If the auction reward recipient is the zero address, no reward will be given.
   * @param _auctionResult Auction result to get reward for
   * @param _reserve Reserve available for the reward
   * @return Reward amount
   */
  function reward(
    AuctionResult memory _auctionResult,
    uint256 _reserve
  ) internal pure returns (uint256) {
    if (_auctionResult.recipient == address(0)) return 0;
    if (_reserve == 0) return 0;
    return
      convert(UD60x18.wrap(UD2x18.unwrap(_auctionResult.rewardFraction)).mul(convert(_reserve)));
  }
}
