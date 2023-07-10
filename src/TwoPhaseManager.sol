// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { IDrawAuction } from "draw-auction-local/interfaces/IDrawAuction.sol";
import { PhaseManager, Phase } from "draw-auction-local/abstract/PhaseManager.sol";
import { RNGRequestor, RNGInterface } from "draw-auction-local/abstract/RNGRequestor.sol";

/// @notice Emitted when the draw auction is set to the zero address
error DrawAuctionZeroAddress();

contract TwoPhaseManager is PhaseManager, RNGRequestor {
  /* ============ Constructor ============ */

  /// @notice Address of the DrawAuction to complete
  IDrawAuction internal immutable _drawAuction;

  /**
   * @notice Contract constructor.
   * @param rng_ Address of the RNG service
   * @param rngTimeout_ Time in seconds before an RNG request can be cancelled
   * @param drawAuction_ Draw auction to complete
   * @param _owner Address of the TwoPhaseManager owner
   */
  constructor(
    RNGInterface rng_,
    uint32 rngTimeout_,
    IDrawAuction drawAuction_,
    address _owner
  ) PhaseManager(2) RNGRequestor(rng_, rngTimeout_, _owner) {
    if (address(drawAuction_) == address(0)) revert DrawAuctionZeroAddress();
    _drawAuction = drawAuction_;
  }

  /* ============ External Functions ============ */

  /* ============ Getters ============ */

  /**
   * @notice The draw auction that is being managed
   * @return IDrawAuction The auction contract
   */
  function drawAuction() external view returns (IDrawAuction) {
    return _drawAuction;
  }

  /* ============ Internal Functions ============ */

  /* ============ Hooks ============ */

  /**
   * @notice Hook called after the RNG request has started.
   * @dev The auction is not aware of the PrizePool contract, so startTime is set to 0.
   *      Since the first phase of the auction starts when the draw has ended,
   *      we can derive the actual startTime by calling PrizePool.hasOpenDrawFinished() when computing the reward.
   * @param _rewardRecipient Address that will receive the auction reward for starting the RNG request
   */
  function _afterRNGStart(address _rewardRecipient) internal override {
    _setPhase(0, 0, uint64(block.timestamp), _rewardRecipient);
    emit AuctionPhaseCompleted(0, msg.sender);
  }

  /**
   * @notice Hook called after the RNG request has completed.
   * @param _randomNumber Random number generated by the RNG service
   * @param _rewardRecipient Address that will receive the auction reward for completing the RNG request
   */
  function _afterRNGComplete(uint256 _randomNumber, address _rewardRecipient) internal override {
    Phase memory _completeRNGPhase = _setPhase(
      1,
      _getPhase(0).endTime,
      uint64(block.timestamp),
      _rewardRecipient
    );
    emit AuctionPhaseCompleted(1, msg.sender);

    Phase[] memory _auctionPhases = new Phase[](2);
    _auctionPhases[0] = _getPhase(0);
    _auctionPhases[1] = _completeRNGPhase;

    _drawAuction.completeAuction(_auctionPhases, _randomNumber);
  }
}
