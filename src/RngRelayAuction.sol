// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/console2.sol";

import { UD2x18 } from "prb-math/UD2x18.sol";
import { convert } from "prb-math/UD60x18.sol";
import { PrizePool } from "pt-v5-prize-pool/PrizePool.sol";

import { RewardLib } from "./libraries/RewardLib.sol";
import { IRngAuctionRelayListener } from "./interfaces/IRngAuctionRelayListener.sol";
import { IAuction, AuctionResult } from "./interfaces/IAuction.sol";
import { RngAuction } from "./RngAuction.sol";

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
error AuctionTargetTimeExceedsDuration(uint64 auctionDuration, uint64 auctionTargetTime);

/// @notice Thrown if the RngAuction address is the zero address.
error RngRelayerZeroAddress();

/// @notice Thrown if the current sequence has already been completed.
error SequenceAlreadyCompleted();

/// @notice Thrown if the current draw auction has expired.
error AuctionExpired();

/// @notice Thrown if the PrizePool address is the zero address.
error PrizePoolZeroAddress();

/**
 * @title   PoolTogether V5 RngRelayAuctionDirect
 * @author  Generation Software Team
 * @notice  This contract sends the results of the draw auction directly to the draw manager.
 */
contract RngRelayAuction is IRngAuctionRelayListener, IAuction {

  event AuctionRewardDistributed(
    uint32 indexed sequenceId,
    address indexed recipient,
    uint32 index,
    uint256 reward
  );

  event RngRelayAuctionCompleted(
    uint32 indexed sequenceId,
    uint32 indexed drawId,
    address indexed rewardRecipient,
    uint64 auctionElapsedSeconds,
    UD2x18 rewardFraction
  );

  /// @notice The PrizePool to send the auction results to
  PrizePool public immutable prizePool;

  address public immutable startRngAuctionRelayer;

  /* ============ Variables ============ */

  /// @notice The sequence ID that was used in the last auction
  uint32 internal _lastSequenceId;

  /// @notice The auction duration in seconds
  uint64 internal _auctionDurationSeconds;

  /// @notice The target time to complete the auction as a fraction of the auction duration
  UD2x18 internal _auctionTargetTimeFraction;

  /// @notice The last completed auction results
  AuctionResult internal _auctionResults;

  /* ============ Constructor ============ */

  /**
   * @notice Deploy the RngRelayAuction smart contract.
   */
  constructor(
    PrizePool prizePool_,
    address _startRngAuctionRelayer,
    uint64 auctionDurationSeconds_,
    uint64 auctionTargetTime_
  ) {
    if (address(prizePool_) == address(0)) revert PrizePoolZeroAddress();
    prizePool = prizePool_;
    if (address(_startRngAuctionRelayer) == address(0)) revert RngRelayerZeroAddress();
    if (auctionDurationSeconds_ == 0) revert AuctionDurationZero();
    if (auctionTargetTime_ == 0) revert AuctionTargetTimeZero();
    if (auctionTargetTime_ > auctionDurationSeconds_) {
      revert AuctionTargetTimeExceedsDuration(auctionDurationSeconds_, auctionTargetTime_);
    }
    startRngAuctionRelayer = _startRngAuctionRelayer;
    _auctionDurationSeconds = auctionDurationSeconds_;
    _auctionTargetTimeFraction = UD2x18.wrap(
      uint64(convert(auctionTargetTime_).div(convert(_auctionDurationSeconds)).unwrap())
    );
  }

  /* ============ External Functions ============ */

  function rngComplete(
    uint256 _randomNumber,
    uint256 _rngCompletedAt,
    address _rewardRecipient,
    uint32 _sequenceId,
    AuctionResult calldata _startRngAuctionResult
  ) external returns (bytes32) {
    console2.log("rngComplete 1");
    if (_canStartNextSequence(_sequenceId)) revert SequenceAlreadyCompleted();
    uint64 _auctionElapsedSeconds = uint64(block.timestamp < _rngCompletedAt ? 0 : block.timestamp - _rngCompletedAt);
    if (_auctionElapsedSeconds > (_auctionDurationSeconds-1)) revert AuctionExpired();
    console2.log("rngComplete 2");
    // Calculate the reward fraction and set the draw auction results
    UD2x18 rewardFraction = _fractionalReward(_auctionElapsedSeconds);
    _auctionResults.rewardFraction = rewardFraction;
    _auctionResults.recipient = _rewardRecipient;
    _lastSequenceId = _sequenceId;

    console2.log("rngComplete 3");

    AuctionResult[] memory auctionResults = new AuctionResult[](2);
    auctionResults[0] = _startRngAuctionResult;
    auctionResults[1] = AuctionResult({
      rewardFraction: rewardFraction,
      recipient: _rewardRecipient
    });

    console2.log("rngComplete 4", _randomNumber);

    uint32 drawId = prizePool.closeDraw(_randomNumber);

    console2.log("rngComplete 5");

    uint256 futureReserve = prizePool.reserve() + prizePool.reserveForOpenDraw();
    uint256[] memory _rewards = RewardLib.rewards(auctionResults, futureReserve);

    console2.log("rngComplete 6");

    emit RngRelayAuctionCompleted(
      _sequenceId,
      drawId,
      _rewardRecipient,
      _auctionElapsedSeconds,
      rewardFraction
    );

    for (uint8 i = 0; i < _rewards.length; i++) {
      uint104 _reward = uint104(_rewards[i]);
      if (_reward > 0) {
        prizePool.withdrawReserve(auctionResults[i].recipient, _reward);
        emit AuctionRewardDistributed(_sequenceId, auctionResults[i].recipient, i, _reward);
      }
    }

    return bytes32(uint(drawId));
  }

  function computeRewards(AuctionResult[] calldata __auctionResults) external returns (uint256[] memory) {
    uint256 totalReserve = prizePool.reserve() + prizePool.reserveForOpenDraw();
    return _computeRewards(__auctionResults, totalReserve);
  }

  function computeRewardsWithTotal(AuctionResult[] calldata __auctionResults, uint256 _totalReserve) external returns (uint256[] memory) {
    return _computeRewards(__auctionResults, _totalReserve);
  }

  function canStartNextSequence(uint32 _sequenceId) external view returns (bool) {
    return _canStartNextSequence(_sequenceId);
  }

  function auctionDuration() external view returns (uint64) {
    return _auctionDurationSeconds;
  }

  function computeRewardFraction(uint64 _auctionElapsedTime) external view returns (UD2x18) {
    return _fractionalReward(_auctionElapsedTime);
  }

  function lastSequenceId() external view returns (uint32) {
    return _lastSequenceId;
  }

  function getLastAuctionResult()
    external
    view
    returns (AuctionResult memory)
  {
    return _auctionResults;
  }

  /* ============ Internal Functions ============ */

  function _computeRewards(AuctionResult[] calldata __auctionResults, uint256 _totalReserve) internal returns (uint256[] memory) {
    return RewardLib.rewards(__auctionResults, _totalReserve);
  }

  /**
   * @notice Calculates if the current auction is complete.
   * @dev The auction is complete when the last recorded auction sequence ID matches the current sequence ID
   * @return True if the auction is complete, false otherwise
   */
  function _canStartNextSequence(uint32 _sequenceId) internal view returns (bool) {
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
