// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { PrizePool } from "v5-prize-pool/PrizePool.sol";

/**
 * @title PoolTogether V5 DrawAuction
 * @author PoolTogether Inc. Team
 * @notice The DrawAuction uses an auction mechanism to incentivize the completion of the Draw.
 *         This mechanism relies on a linear interpolation to incentivizes anyone to start and complete the Draw.
 *         The first user to complete the Draw gets rewarded with the partial or full PrizePool reserve amount.
 */
contract DrawAuction {
  /* ============ Variables ============ */

  /// @notice Duration of the auction in seconds.
  uint32 internal _auctionDuration;

  /// @notice Instance of the PrizePool to compute Draw for.
  PrizePool internal _prizePool;

  /// @notice Seconds between draws.
  uint32 internal _drawPeriodSeconds;

  /* ============ Custom Errors ============ */

  /// @notice Thrown when the PrizePool address passed to the constructor is zero address.
  error PrizePoolNotZeroAddress();

  /// @notice Thrown when the Draw period seconds passed to the constructor is zero.
  error DrawPeriodSecondsNotZero();

  /* ============ Constructor ============ */

  /**
   * @notice Contract constructor.
   * @dev We pass the `drawPeriodSeconds` cause the PrizePool we want to interact with may live on L2.
   * @param prizePool_ Address of the prize pool
   * @param drawPeriodSeconds_ Draw period in seconds
   * @param auctionDuration_ Duration of the auction in seconds
   */
  constructor(PrizePool prizePool_, uint32 drawPeriodSeconds_, uint32 auctionDuration_) {
    _prizePool = prizePool_;
    _drawPeriodSeconds = drawPeriodSeconds_;
    _auctionDuration = auctionDuration_;
  }

  /* ============ External Functions ============ */

  /**
   * @notice Complete the current Draw and start the next one.
   * @param winningRandomNumber_ The winning random number for the current Draw
   * @return Reward amount
   */
  function completeAndStartNextDraw(uint256 winningRandomNumber_) external returns (uint256) {
    uint256 _rewardAmount = _reward();

    _prizePool.completeAndStartNextDraw(winningRandomNumber_);
    _prizePool.withdrawReserve(msg.sender, uint104(_rewardAmount));

    return _rewardAmount;
  }

  /* ============ Getter Functions ============ */

  /**
   * @notice Duration of the auction.
   * @dev This is the time it takes for the auction to reach the PrizePool full reserve amount.
   * @return Duration of the auction in seconds
   */
  function auctionDuration() external view returns (uint256) {
    return _auctionDuration;
  }

  /**
   * @notice Prize Pool instance for which the Draw is triggered.
   * @return Prize Pool instance
   */
  function prizePool() external view returns (PrizePool) {
    return _prizePool;
  }

  /**
   * @notice Current reward for calling `completeAndStartNextDraw`.
   * @return Reward amount
   */
  function reward() external view returns (uint256) {
    return _reward();
  }

  /* ============ Internal Functions ============ */

  /**
   * @notice Current reward for calling `completeAndStartNextDraw`.
   * @dev The reward amount is computed via linear interpolation starting from 0
   *      and increasing as the auction goes on to the full reserve amount.
   * @return Reward amount
   */
  function _reward() internal view returns (uint256) {
    uint256 _nextDrawEndsAt = _prizePool.nextDrawEndsAt();

    if (block.timestamp < _nextDrawEndsAt) {
      return 0;
    }

    uint256 _reserve = _prizePool.reserve() + _prizePool.reserveForNextDraw();
    uint256 _elapsedTime = block.timestamp - _nextDrawEndsAt;

    return
      _elapsedTime >= _auctionDuration ? _reserve : (_elapsedTime * _reserve) / _auctionDuration;
  }
}
