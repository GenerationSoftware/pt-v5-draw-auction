// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Phase } from "../abstract/PhaseManager.sol";

import { UD2x18 } from "prb-math/UD2x18.sol";
import { UD60x18, toUD60x18, fromUD60x18 } from "prb-math/UD60x18.sol";

library RewardLib {
  /* ============ Internal Functions ============ */

  /**
   * @notice Calculates a linearly increasing fraction from the elapsed time divided by the auction duration.
   * @dev This function does not do any checks to see if the elapsed time is greater than the auction duration.
   * @return The reward portion as a UD2x18 fraction
   */
  function rewardPortion(uint64 _elapsedTime, uint64 _auctionDuration) internal pure returns (UD2x18) {
    UD2x18.wrap(uint64(toUD60x18(_elapsedTime).div(toUD60x18(_auctionDuration)).unwrap()));
  }

  /**
   * @notice Calculates rewards to distribute given the available reserve and completed auction phases.
   * @dev Each phase takes a portion of the remaining reserve. This means that if the reserve is equal
   * to 100 and the first phase takes 50% and the second takes 50%, then the first reward will be equal
   * to 50 while the second will be 25.
   * @param _phases Phases to get reward for
   * @param _reserve Reserve available for the rewards
   * @return Rewards in the same order as the phases they correspond to
   */
  function rewards(
    Phase[] memory _phases,
    uint256 _reserve
  ) internal view returns (uint256[] memory) {
    uint256 _phasesLength = _phases.length;
    uint256[] memory _rewards = new uint256[](_phasesLength);
    for (uint256 i; i < _phasesLength; i++) {
      _rewards[i] = reward(_phases[i], _reserve);
      _reserve = _reserve - _rewards[i];
    }
    return _rewards;
  }

  /**
   * @notice Calculates the reward for the given phase and available reserve.
   * @dev If the phase reward recipient is the zero address, no reward will be given.
   * @param _phase Phase to get reward for
   * @param _reserve Reserve available for the reward
   * @return Reward amount
   */
  function reward(
    Phase memory _phase,
    uint256 _reserve
  ) internal view returns (uint256) {
    if (_phase.recipient == address(0)) return 0;
    if (_reserve == 0) return 0;
    return fromUD60x18(UD60x18.wrap(UD2x18.unwrap(_phase.rewardPortion)).mul(toUD60x18(_reserve)));
  }
}
