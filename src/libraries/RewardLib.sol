// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { PrizePool } from "v5-prize-pool/PrizePool.sol";

import { AuctionLib } from "src/libraries/AuctionLib.sol";

import { console2 } from "forge-std/console2.sol";

library RewardLib {
  /**
   * @notice Current reward for completing the Auction phase.
   * @dev The reward amount is computed via linear interpolation starting from 0
   *      and increasing as the auction goes on to the full reserve amount.
   * @param _phaseId ID of the phase to get reward for
   * @param _prizePool Address of the Prize Pool to get auction reward for
   * @param _auctionDuration Duration of the auction in seconds
   * @return Reward amount
   */
  function getReward(
    AuctionLib.Phase[] memory _phases,
    uint8 _phaseId,
    PrizePool _prizePool,
    uint256 _auctionDuration
  ) internal view returns (uint256) {
    // TODO: which value would nextDrawEndsAt return if the draw has been awarded?
    uint64 _nextDrawEndsAt = _prizePool.nextDrawEndsAt();

    console2.log("_reward block.timestamp", block.timestamp);
    console2.log("_reward _nextDrawEndsAt", _nextDrawEndsAt);
    console2.log("_reward _prizePool.nextDrawStartsAt()", _prizePool.nextDrawStartsAt());
    console2.log("_reward periodDiff", _nextDrawEndsAt - _prizePool.nextDrawStartsAt());

    // If the Draw has not ended yet, we return 0
    if (block.timestamp <= _nextDrawEndsAt) {
      return 0;
    }

    AuctionLib.Phase memory _phase = _phases[_phaseId];
    uint256 _elapsedTime;

    if (_phase.id == 0) {
      // Elapsed time between the timestamp at which the Draw ended and the first phase end time
      // End time will be block.timestamp if this phase has not been triggered yet
      // Is unchecked since block.timestamp can't be lower than nextDrawEndsAt
      unchecked {
        _elapsedTime = (_phase.endTime != 0 ? _phase.endTime : block.timestamp) - _nextDrawEndsAt;
        console2.log("_reward _phase.startTime", _phase.startTime);
        console2.log("_reward _elapsedTime", _elapsedTime);
      }
    } else {
      // Retrieve the previous phase
      AuctionLib.Phase memory _previousPhase = _phases[_phase.id - 1];

      // If the previous phase has not been triggered,
      // we return 0 cause we can't compute reward for this phase
      if (_previousPhase.endTime == 0) {
        return 0;
      }

      // Elapsed time between this phase startTime and endTime
      // If startTime is different than 0, it means that this phase has been recorded and endTime is also set
      // End time will be block.timestamp if this phase has not been triggered yet
      // Is unchecked since block.timestamp can't be lower than previousPhase.endTime
      unchecked {
        _elapsedTime = _phase.startTime != 0
          ? _phase.endTime - _phase.startTime
          : block.timestamp - _previousPhase.endTime;
      }
    }

    uint256 _reserve = _prizePool.reserve() + _prizePool.reserveForNextDraw();

    // We can't award more than the available reserve
    // TODO: look at _nextDrawEndsAt in the PrizePool to figure out if the auction duration could be extended
    if (_elapsedTime >= _auctionDuration) {
      return _reserve;
    }

    console2.log("_elapsedTime", _elapsedTime);

    return (_elapsedTime * _reserve) / _auctionDuration;
  }
}
