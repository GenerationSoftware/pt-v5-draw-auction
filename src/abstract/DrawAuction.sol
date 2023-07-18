// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { RNGInterface } from "rng/RNGInterface.sol";
import { UD2x18 } from "prb-math/UD2x18.sol";

import { PhaseManager, Phase } from "local-draw-auction/abstract/PhaseManager.sol";
import { RewardLib } from "local-draw-auction/libraries/RewardLib.sol";
import { RngAuction } from "local-draw-auction/RngAuction.sol";

/**
 * @title   PoolTogether V5 DrawAuction
 * @author  Generation Software Team
 * @notice  The DrawAuction uses an auction mechanism to incentivize the completion of the Draw.
 *          There is a draw auction for each prize pool. The draw auction starts when the new
 *          random number is available for the current draw.
 * @dev     This contract runs synchronously with the RngAuction contract, waiting till the RNG
 *          auction is complete and the random number is available before starting the draw
 *          auction.
 */
abstract contract DrawAuction is PhaseManager {
  /* ============ Constants ============ */

  /// @notice The RNG Auction to get the random number from
  RngAuction public immutable rngAuction;

  /// @notice The auction duration in seconds
  uint64 public immutable auctionDurationSeconds;

  /* ============ Variables ============ */

  /// @notice The RNG request ID that was used in the last auction
  uint32 internal _lastRngRequestId;

  /* ============ Custom Errors ============ */

  /// @notice Thrown if the auction period is zero.
  error AuctionDurationZero();

  /// @notice Thrown if the RngAuction address is the zero address.
  error RngAuctionZeroAddress();

  /// @notice Thrown if the current draw is already completed.
  error DrawAlreadyCompleted();

  /// @notice Thrown if the RNG request is not completed.
  error RngNotCompleted();

  /// @notice Thrown if the current draw auction has expired.
  error DrawAuctionExpired();

  /* ============ Events ============ */

  /**
   * @notice Emitted when the draw auction is completed.
   * @param completedBy The address that completed the draw auction
   * @param rewardRecipient The recipient of the auction reward
   * @param rngRequestId The ID of the RNG request that was used for the random number
   * @param rewardPortion The portion of the available reserve that will be rewarded
   */
  event DrawAuctionCompleted(
    address indexed completedBy,
    address indexed rewardRecipient,
    uint32 rngRequestId,
    UD2x18 rewardPortion
  );

  /* ============ Constructor ============ */

  /**
   * @notice Deploy the DrawAuction smart contract.
   * @param rngAuction_ The RngAuction to get the random number from
   * @param auctionDurationSeconds_ Auction duration in seconds
   */
  constructor(RngAuction rngAuction_, uint64 auctionDurationSeconds_) PhaseManager() {
    if (address(rngAuction_) == address(0)) revert RngAuctionZeroAddress();
    if (auctionDurationSeconds_ == 0) revert AuctionDurationZero();
    rngAuction = rngAuction_;
    auctionDurationSeconds = auctionDurationSeconds_;
  }

  /* ============ External Functions ============ */

  /**
   * @notice Completes the current draw with the random number from the RngAuction.
   * @param _rewardRecipient The address to send the reward to
   */
  function completeDraw(address _rewardRecipient) external {
    uint32 _rngRequestId = rngAuction.getRngRequestId();
    if (_rngRequestId == _lastRngRequestId) revert DrawAlreadyCompleted();
    if (!rngAuction.isRngCompleted()) revert RngNotCompleted();

    RNGInterface _rng = rngAuction.getRngService();
    uint64 _auctionElapsedSeconds = uint64(block.timestamp) - _rng.completedAt(_rngRequestId);
    if (_auctionElapsedSeconds > auctionDurationSeconds) revert DrawAuctionExpired();

    // Calculate the reward portion and set the draw auction phase
    UD2x18 _rewardPortion = RewardLib.rewardPortion(_auctionElapsedSeconds, auctionDurationSeconds);
    _setPhase(_rewardPortion, _rewardRecipient);

    // Hook after draw auction is complete
    _afterCompleteDraw(_rng.randomNumber(_rngRequestId));

    emit DrawAuctionCompleted(msg.sender, _rewardRecipient, _rngRequestId, _rewardPortion);
  }

  /**
   * @notice Hook called after the draw auction is completed.
   * @param _randomNumber The random number from the auction
   * @dev Override this in a parent contract to send the random number and auction results to
   * the DrawController or to add more phases if needed for multi-stage bridging.
   */
  function _afterCompleteDraw(uint256 _randomNumber) internal virtual {}

  /**
   * @notice Computes if the current draw can be completed.
   * @return True if the current draw can be completed, false otherwise
   * @dev Use this to determine if all the requirements to call `completeDraw` are met.
   */
  function canCompleteDraw() external view returns (bool) {
    RNGInterface _rng = rngAuction.getRngService();
    uint32 _rngRequestId = rngAuction.getRngRequestId();
    uint64 _auctionElapsedSeconds = uint64(block.timestamp) - _rng.completedAt(_rngRequestId);
    return (_rngRequestId != _lastRngRequestId &&
      rngAuction.isRngCompleted() &&
      _auctionElapsedSeconds <= auctionDurationSeconds);
  }
}
