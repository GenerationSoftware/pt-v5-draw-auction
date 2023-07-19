// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { RNGInterface } from "rng/RNGInterface.sol";
import { UD2x18 } from "prb-math/UD2x18.sol";

import { PhaseManager, Phase } from "local-draw-auction/abstract/PhaseManager.sol";
import { RewardLib } from "local-draw-auction/libraries/RewardLib.sol";
import { RngAuction } from "local-draw-auction/RngAuction.sol";
import { IAuction } from "local-draw-auction/interfaces/IAuction.sol";

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
abstract contract DrawAuction is PhaseManager, IAuction {
  /* ============ Constants ============ */

  /// @notice The RNG Auction to get the random number from
  RngAuction public immutable rngAuction;

  /* ============ Variables ============ */

  /// @notice The sequence ID that was used in the last auction
  uint32 internal _lastSequenceId;

  /// @notice The auction duration in seconds
  uint64 internal _auctionDurationSeconds;

  /* ============ Custom Errors ============ */

  /// @notice Thrown if the auction period is zero.
  error AuctionDurationZero();

  /// @notice Thrown if the RngAuction address is the zero address.
  error RngAuctionZeroAddress();

  /// @notice Thrown if the current draw auction has already been completed.
  error DrawAlreadyCompleted();

  /// @notice Thrown if the current draw auction has expired.
  error DrawAuctionExpired();

  /* ============ Events ============ */

  /**
   * @notice Emitted when the draw auction is completed.
   * @param rewardRecipient The recipient of the auction reward
   * @param sequenceId The sequence ID of the auction
   * @param rewardPortion The portion of the available reserve that will be rewarded
   */
  event DrawAuctionCompleted(
    address indexed rewardRecipient,
    uint32 indexed sequenceId,
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
    _auctionDurationSeconds = auctionDurationSeconds_;
  }

  /* ============ External Functions ============ */

  /**
   * @notice Completes the current draw with the random number from the RngAuction.
   * @param _rewardRecipient The address to send the reward to
   */
  function completeAuction(address _rewardRecipient) external {
    (RngAuction.RngRequest memory _rngRequest, uint64 _rngCompletedAt) = rngAuction.getResults();
    if (_isAuctionComplete()) revert DrawAlreadyCompleted();

    uint64 _auctionElapsedSeconds = uint64(block.timestamp) - _rngCompletedAt;
    if (_auctionElapsedSeconds > _auctionDurationSeconds) revert DrawAuctionExpired();

    // Calculate the reward portion and set the draw auction phase
    UD2x18 _rewardPortion = RewardLib.rewardPortion(
      _auctionElapsedSeconds,
      _auctionDurationSeconds
    );
    _setPhase(_rewardPortion, _rewardRecipient);
    _lastSequenceId = _rngRequest.sequenceId;

    // Hook after draw auction is complete
    _afterDrawAuction(rngAuction.randomNumber());

    emit DrawAuctionCompleted(_rewardRecipient, _rngRequest.sequenceId, _rewardPortion);
  }

  /* ============ IAuction Functions ============ */

  /**
   * @inheritdoc IAuction
   */
  function isAuctionComplete() external view returns (bool) {
    return _isAuctionComplete();
  }

  /**
   * @inheritdoc IAuction
   */
  function elapsedTime() external view returns (uint64) {
    (, uint64 _rngCompletedAt) = rngAuction.getResults();
    return uint64(block.timestamp) - _rngCompletedAt;
  }

  /**
   * @inheritdoc IAuction
   */
  function auctionDuration() external view returns (uint64) {
    return _auctionDurationSeconds;
  }

  /**
   * @inheritdoc IAuction
   */
  function currentRewardPortion() external view returns (UD2x18) {
    (, uint64 _rngCompletedAt) = rngAuction.getResults();
    uint64 _auctionElapsedSeconds = uint64(block.timestamp) - _rngCompletedAt;
    return RewardLib.rewardPortion(_auctionElapsedSeconds, _auctionDurationSeconds);
  }

  /* ============ Internal Functions ============ */

  /**
   * @notice Calculates if the current auction is complete.
   * @dev The auction is complete when the last recorded auction sequence ID matches the current sequence ID
   * @return True if the auction is complete, false otherwise
   */
  function _isAuctionComplete() internal view returns (bool) {
    return _lastSequenceId == rngAuction.currentSequenceId();
  }

  /* ============ Hooks ============ */

  /**
   * @notice Hook called after the draw auction is completed.
   * @param _randomNumber The random number from the auction
   * @dev Override this in a parent contract to send the random number and auction results to
   * the DrawController or to add more phases if needed for multi-stage bridging.
   */
  function _afterDrawAuction(uint256 _randomNumber) internal virtual {}
}