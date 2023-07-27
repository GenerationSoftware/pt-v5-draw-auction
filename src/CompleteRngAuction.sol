// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RNGInterface } from "rng/RNGInterface.sol";
import { UD2x18 } from "prb-math/UD2x18.sol";
import { UD60x18, convert } from "prb-math/UD60x18.sol";

import { RewardLib } from "local-draw-auction/libraries/RewardLib.sol";
import { StartRngAuction } from "local-draw-auction/StartRngAuction.sol";
import { IAuction, AuctionResults } from "local-draw-auction/interfaces/IAuction.sol";

import { DrawAuction } from "local-draw-auction/abstract/DrawAuction.sol";
import { StartRngAuction } from "local-draw-auction/StartRngAuction.sol";
import { IDrawManager } from "local-draw-auction/interfaces/IDrawManager.sol";
import { AuctionResults } from "local-draw-auction/interfaces/IAuction.sol";
import { IStartRngAuctionRelayListener } from "local-draw-auction/interfaces/IStartRngAuctionRelayListener.sol";

/**
 * @title   PoolTogether V5 DrawAuctionDirect
 * @author  Generation Software Team
 * @notice  This contract sends the results of the draw auction directly to the draw manager.
 */
contract CompleteRngAuction is IStartRngAuctionRelayListener {
  /* ============ Constants ============ */

  /// @notice The DrawManager to send the auction results to
  IDrawManager public immutable drawManager;

  address public immutable startRngAuctionRelayer;

  /* ============ Variables ============ */

  /// @notice The sequence ID that was used in the last auction
  uint32 internal _lastSequenceId;

  /// @notice The auction duration in seconds
  uint64 internal _auctionDurationSeconds;

  /// @notice The target time to complete the auction as a fraction of the auction duration
  UD2x18 internal _auctionTargetTimeFraction;

  /// @notice The last completed auction results
  AuctionResults internal _auctionResults;

  /* ============ Custom Errors ============ */

  /// @notice Thrown if the auction period is zero.
  error AuctionDurationZero();

  /// @notice Thrown if the auction target time is zero.
  error AuctionTargetTimeZero();

  /**
   * @notice Thrown if the auction target time exceeds the auction duration.
   * @param auctionTargetTime The auction target time to complete in seconds
   * @param auctionDuration The auction duration in seconds
   */
  error AuctionTargetTimeExceedsDuration(uint64 auctionTargetTime, uint64 auctionDuration);

  /// @notice Thrown if the StartRngAuction address is the zero address.
  error RngRelayerZeroAddress();

  /// @notice Thrown if the current sequence has already been completed.
  error SequenceAlreadyCompleted();

  /// @notice Thrown if the current draw auction has expired.
  error AuctionExpired();

  /* ============ Custom Errors ============ */

  /// @notice Thrown if the DrawManager address is the zero address.
  error DrawManagerZeroAddress();

  /* ============ Constructor ============ */

  /**
   * @notice Deploy the DrawAuction smart contract.
   * @param drawManager_ The DrawManager to send the auction results to
   * @param rngAuction_ The StartRngAuction to get the random number from
   * @param auctionDurationSeconds_ Auction duration in seconds
   * @param auctionTargetTime_ Auction target time to complete in seconds
   */
  constructor(
    IDrawManager drawManager_,
    address _startRngAuctionRelayer,
    uint64 auctionDurationSeconds_,
    uint64 auctionTargetTime_
  ) {
    if (address(drawManager_) == address(0)) revert DrawManagerZeroAddress();
    drawManager = drawManager_;
    if (address(_startRngAuctionRelayer) == address(0)) revert RngRelayerZeroAddress();
    if (auctionDurationSeconds_ == 0) revert AuctionDurationZero();
    if (auctionTargetTime_ == 0) revert AuctionTargetTimeZero();
    if (auctionTargetTime_ > auctionDurationSeconds_) {
      revert AuctionTargetTimeExceedsDuration(auctionTargetTime_, auctionDurationSeconds_);
    }
    rngAuction = rngAuction_;
    _auctionDurationSeconds = auctionDurationSeconds_;
    _auctionTargetTimeFraction = UD2x18.wrap(
      uint64(convert(auctionTargetTime_).div(convert(_auctionDurationSeconds)).unwrap())
    );
  }

  /* ============ External Functions ============ */

  function rngComplete(
    uint256 _randomNumber,
    uint56 _rngCompletedAt,
    address _rewardRecipient,
    uint32 _sequenceId,
    AuctionResults calldata _startRngAuctionResult
  ) external {
    if (_isAuctionComplete(sequenceId)) revert SequenceAlreadyCompleted();

    uint64 _auctionElapsedSeconds = uint64(block.timestamp) - _rngCompletedAt;
    if (_auctionElapsedSeconds > _auctionDurationSeconds) revert AuctionExpired();

    // Calculate the reward fraction and set the draw auction results
    UD2x18 _reward = _fractionalReward(_auctionElapsedSeconds);
    _auctionResults.rewardFraction = _reward;
    _auctionResults.recipient = _rewardRecipient;
    _lastSequenceId = _sequenceId;

    AuctionResults[] memory _results = new AuctionResults[](2);
    _results[0] = _startRngAuctionResult;
    _results[1] = _auctionResults;
    
    drawManager.closeDraw(_randomNumber, _results);

    emit AuctionCompleted(
      _rewardRecipient,
      _sequenceId,
      _auctionElapsedSeconds,
      _reward
    );
  }

  /* ============ IAuction Functions ============ */

  /**
   * @inheritdoc IAuction
   */
  function isAuctionComplete(uint32 sequenceId) external view returns (bool) {
    return _isAuctionComplete(sequenceId);
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
  function fractionalReward(uint elapsedTime) external view returns (UD2x18) {
    return _fractionalReward(elapsedTime);
  }

  /**
   * @inheritdoc IAuction
   */
  function currentRewardAmount(uint256 _reserve) external view returns (uint256) {
    AuctionResults[] memory _results = new AuctionResults[](2);
    (_results[0], ) = rngAuction.getAuctionResults();
    _results[1] = AuctionResults(msg.sender, _fractionalReward(elapsedTime()));
    return RewardLib.rewards(_results, _reserve)[1];
  }

  /**
   * @inheritdoc IAuction
   */
  function getAuctionResults()
    external
    view
    returns (AuctionResults memory auctionResults, uint32 sequenceId)
  {
    return (_auctionResults, _lastSequenceId);
  }

  /* ============ Internal Functions ============ */

  /**
   * @notice Calculates if the current auction is complete.
   * @dev The auction is complete when the last recorded auction sequence ID matches the current sequence ID
   * @return True if the auction is complete, false otherwise
   */
  function _isAuctionComplete(uint32 _sequenceId) internal view returns (bool) {
    return _lastSequenceId >= _sequenceId;
  }

  /**
   * @notice Calculates the reward fraction for an auction if it were to be completed after the elapsed time.
   * @dev Uses the last sold fraction as the target price for this auction.
   * @return The reward fraction as a UD2x18 value
   */
  function _fractionalReward(uint64 _elapsedSeconds) internal view returns (UD2x18) {
    return
      RewardLib.fractionalReward(
        _elapsedSeconds,
        _auctionDurationSeconds,
        _auctionTargetTimeFraction,
        _auctionResults.rewardFraction
      );
  }
}
