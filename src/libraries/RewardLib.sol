// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { AuctionResults } from "local-draw-auction/interfaces/IAuction.sol";

import { UD2x18 } from "prb-math/UD2x18.sol";
import { UD60x18, toUD60x18, fromUD60x18 } from "prb-math/UD60x18.sol";

library RewardLib {
  /* ============ Internal Functions ============ */

  /**
   * @notice Calculates a linearly increasing fraction from the elapsed time divided by the auction duration.
   * @dev This function does not do any checks to see if the elapsed time is greater than the auction duration.
   * @return The reward fraction as a UD2x18 fraction
   */
  function fractionalReward(
    uint64 _elapsedTime,
    uint64 _auctionDuration
  ) internal pure returns (UD2x18) {
    return UD2x18.wrap(uint64(toUD60x18(_elapsedTime).div(toUD60x18(_auctionDuration)).unwrap()));
  }

  /**
   * @notice Calculates rewards to distribute given the available reserve and completed auction results.
   * @dev Each auction takes a fraction of the remaining reserve. This means that if the reserve is equal
   * to 100 and the first auction takes 50% and the second takes 50%, then the first reward will be equal
   * to 50 while the second will be 25.
   * @param _auctionResults Auction results to get rewards for
   * @param _reserve Reserve available for the rewards
   * @return Rewards in the same order as the auction results they correspond to
   */
  function rewards(
    AuctionResults[] memory _auctionResults,
    uint256 _reserve
  ) internal pure returns (uint256[] memory) {
    uint256 _auctionResultsLength = _auctionResults.length;
    uint256[] memory _rewards = new uint256[](_auctionResultsLength);
    for (uint256 i; i < _auctionResultsLength; i++) {
      _rewards[i] = reward(_auctionResults[i], _reserve);
      _reserve = _reserve - _rewards[i];
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
    AuctionResults memory _auctionResult,
    uint256 _reserve
  ) internal pure returns (uint256) {
    if (_auctionResult.recipient == address(0)) return 0;
    if (_reserve == 0) return 0;
    return
      fromUD60x18(
        UD60x18.wrap(UD2x18.unwrap(_auctionResult.rewardFraction)).mul(toUD60x18(_reserve))
      );
  }
}
