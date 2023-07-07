// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { PrizePool } from "v5-prize-pool/PrizePool.sol";

import { AuctionLib } from "../libraries/AuctionLib.sol";

library RewardLib {
  /* ============ Internal Functions ============ */

  /**
   * @notice Reward for completing the Auction.
   * @dev The reward amount is computed via linear interpolation starting from 0
   *      and increasing as the auction goes on to the full reserve amount.
   * @dev Only computes reward for the recorded phases passed to the function.
   *      To compute the current reward for a specific phase, use the `reward` function.
   * @param _phases Phases to get reward for
   * @param _prizePool Address of the Prize Pool to get auction reward for
   * @param _auctionDuration Duration of the auction in seconds
   * @return Rewards ordered by phase ID
   */
  function rewards(
    AuctionLib.Phase[] memory _phases,
    PrizePool _prizePool,
    uint32 _auctionDuration
  ) internal view returns (uint256[] memory) {
    uint64 _auctionStart = _prizePool.openDrawEndsAt();
    uint64 _auctionEnd = _auctionStart + _auctionDuration;
    uint256 _reserve = _prizePool.reserve() + _prizePool.reserveForOpenDraw();

    uint256 _phasesLength = _phases.length;
    uint256[] memory _rewards = new uint256[](_phasesLength);

    for (uint256 i; i < _phasesLength; i++) {
      _rewards[i] = _reward(_phases[i], _reserve, _auctionStart, _auctionEnd, _auctionDuration);
    }

    return _rewards;
  }

  /**
   * @notice Reward for completing the Auction phase.
   * @dev The reward amount is computed via linear interpolation starting from 0
   *      and increasing as the auction goes on to the full reserve amount.
   * @dev This implementation assumes that phases are run sequentially, i.e. timestamps should not overlap.
   *      This is to avoid overdistributing the reserve.
   * @param _phase Phase to get reward for
   * @param _prizePool Address of the Prize Pool to get auction reward for
   * @param _auctionDuration Duration of the auction in seconds
   * @return Reward amount
   */
  function reward(
    AuctionLib.Phase memory _phase,
    PrizePool _prizePool,
    uint32 _auctionDuration
  ) internal view returns (uint256) {
    uint64 _auctionStart = _prizePool.openDrawEndsAt();
    uint64 _auctionEnd = _auctionStart + _auctionDuration;

    uint256 _reserve = _prizePool.reserve() + _prizePool.reserveForOpenDraw();

    return _reward(_phase, _reserve, _auctionStart, _auctionEnd, _auctionDuration);
  }

  /* ============ Private Functions ============ */

  /**
   * @notice Reward for completing the Auction phase.
   * @dev The reward amount is computed via linear interpolation starting from 0
   *      and increasing as the auction goes on to the full reserve amount.
   * @dev This implementation assumes that phases are run sequentially, i.e. timestamps should not overlap.
   *      This is to avoid overdistributing the reserve.
   * @param _phase Phase to get reward for
   * @param _reserve Reserve amount
   * @param _auctionStart Auction start time
   * @param _auctionEnd Auction end time
   * @param _auctionDuration Duration of the auction in seconds
   * @return Reward amount
   */
  function _reward(
    AuctionLib.Phase memory _phase,
    uint256 _reserve,
    uint64 _auctionStart,
    uint64 _auctionEnd,
    uint32 _auctionDuration
  ) private view returns (uint256) {
    // If the auction has not started yet, we return 0
    if (block.timestamp <= _auctionStart) {
      return 0;
    }

    // Since the Auction contract is not aware of the PrizePool contract,
    // the first phase start time is set to 0, so we need to set it here instead
    if (_phase.id == 0 && _phase.startTime == 0) {
      _phase.startTime = _auctionStart;
    }

    // If the phase was started before the start of the auction
    // or after the end of the auction, no reward should be distributed
    if (_phase.startTime < _auctionStart || _phase.startTime > _auctionEnd) {
      return 0;
    }

    // If the phase end time has not been set, we use the current time
    if (_phase.endTime == 0) {
      _phase.endTime = uint64(block.timestamp);
    }

    // If the phase was started before the end of the auction,
    // but completed after, the end time should be the auction end time
    // to avoid overdistributing the reserve
    if (_phase.endTime > _auctionEnd) {
      _phase.endTime = _auctionEnd;
    }

    return ((_phase.endTime - _phase.startTime) * _reserve) / _auctionDuration;
  }
}
