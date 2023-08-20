// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { UD2x18 } from "prb-math/UD2x18.sol";
import { convert } from "prb-math/UD60x18.sol";
import { PrizePool } from "pt-v5-prize-pool/PrizePool.sol";
import { SafeCast } from "openzeppelin/utils/math/SafeCast.sol";

import { RewardLib } from "./libraries/RewardLib.sol";
import { IRngAuctionRelayListener } from "./interfaces/IRngAuctionRelayListener.sol";
import { IAuction, AuctionResult } from "./interfaces/IAuction.sol";
import { RngAuction } from "./RngAuction.sol";

/* ============ Custom Errors ============ */

/// @notice Thrown if the auction period is zero.
error AuctionDurationZero();

/// @notice Thrown if the auction target time is zero.
error AuctionTargetTimeZero();

/// @notice Thrown if the caller is not the relayer.
error UnauthorizedRelayer(address relayer);

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
 * @title   RngRelayAuction
 * @author  G9 Software Inc.
 * @notice  This contract auctions off the RNG relay, then closes the Prize Pool using the RNG results.
 */
contract RngRelayAuction is IRngAuctionRelayListener, IAuction {

  /// @notice Emitted for each auction that is rewarded within the sequence.
  /// @dev Not that the reward fractions compound
  /// @param sequenceId The sequence ID of the auction
  /// @param recipient The recipient of the reward
  /// @param index The order in which this reward occurred
  /// @param reward The reward amount
  event AuctionRewardDistributed(
    uint32 indexed sequenceId,
    address indexed recipient,
    uint32 index,
    uint256 reward
  );

  /// @notice Emitted once when the sequence is completed and the Prize Pool draw is closed.
  /// @param sequenceId The sequence id
  /// @param drawId The draw id that was closed
  event RngSequenceCompleted(
    uint32 indexed sequenceId,
    uint32 indexed drawId
  );

  /// @notice The PrizePool whose draw wil be closed.
  PrizePool public immutable prizePool;

  /// @notice The relayer that RNG results must originate from.
  /// @dev Note that this may be a Remote Owner if relayed over an ERC-5164 bridge.
  address public immutable rngAuctionRelayer;

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

  /// @notice Construct a new contract
  /// @param prizePool_ The target Prize Pool to close draws for
  /// @param _rngAuctionRelayer The relayer that RNG results must originate from
  /// @param auctionDurationSeconds_ The auction duration in seconds
  /// @param auctionTargetTime_ The target time to complete the auction
  constructor(
    PrizePool prizePool_,
    address _rngAuctionRelayer,
    uint64 auctionDurationSeconds_,
    uint64 auctionTargetTime_
  ) {
    if (address(prizePool_) == address(0)) revert PrizePoolZeroAddress();
    prizePool = prizePool_;
    if (address(_rngAuctionRelayer) == address(0)) revert RngRelayerZeroAddress();
    if (auctionDurationSeconds_ == 0) revert AuctionDurationZero();
    if (auctionTargetTime_ == 0) revert AuctionTargetTimeZero();
    if (auctionTargetTime_ > auctionDurationSeconds_) {
      revert AuctionTargetTimeExceedsDuration(auctionDurationSeconds_, auctionTargetTime_);
    }
    rngAuctionRelayer = _rngAuctionRelayer;
    _auctionDurationSeconds = auctionDurationSeconds_;
    _auctionTargetTimeFraction = UD2x18.wrap(
      uint64(convert(auctionTargetTime_).div(convert(_auctionDurationSeconds)).unwrap())
    );
  }

  /* ============ External Functions ============ */

  /// @notice Called by the relayer to complete the Rng relay auction.
  /// @param _randomNumber The random number that was generated
  /// @param _rngCompletedAt The timestamp that the RNG was completed at
  /// @param _rewardRecipient The recipient of the relay auction reward
  /// @param _sequenceId The sequence ID of the auction
  /// @param _rngAuctionResult The result of the RNG auction
  function rngComplete(
    uint256 _randomNumber,
    uint256 _rngCompletedAt,
    address _rewardRecipient,
    uint32 _sequenceId,
    AuctionResult calldata _rngAuctionResult
  ) external onlyRngAuctionRelayer requireAuctionOpen(_sequenceId, _rngCompletedAt) returns (bytes32) {
    // Calculate the reward fraction and set the draw auction results
    UD2x18 rewardFraction = _fractionalReward(SafeCast.toUint64(_computeElapsed(_rngCompletedAt)));
    _auctionResults.rewardFraction = rewardFraction;
    _auctionResults.recipient = _rewardRecipient;
    _lastSequenceId = _sequenceId;

    AuctionResult[] memory auctionResults = new AuctionResult[](2);
    auctionResults[0] = _rngAuctionResult;
    auctionResults[1] = AuctionResult({
      rewardFraction: rewardFraction,
      recipient: _rewardRecipient
    });

    uint32 drawId = prizePool.closeDraw(_randomNumber);

    uint256 reserve = prizePool.reserve();
    uint256[] memory _rewards = RewardLib.rewards(auctionResults, reserve);

    emit RngSequenceCompleted(
      _sequenceId,
      drawId
    );

    for (uint8 i = 0; i < _rewards.length; i++) {
      uint96 _reward = _safeCast(_rewards[i]);
      if (_reward > 0) {
        prizePool.withdrawReserve(auctionResults[i].recipient, _reward);
        emit AuctionRewardDistributed(_sequenceId, auctionResults[i].recipient, i, _reward);
      }
    }

    return bytes32(uint(drawId));
  }

  /// @notice Computes the actual rewards that will be distributed to the recipients using the current Prize Pool reserve.
  /// @param __auctionResults The auction results to use for calculation
  /// @return rewards The rewards that will be distributed
  function computeRewards(AuctionResult[] calldata __auctionResults) external view returns (uint256[] memory) {
    uint256 totalReserve = prizePool.reserve() + prizePool.reserveForOpenDraw();
    return _computeRewards(__auctionResults, totalReserve);
  }

  /// @notice Computes the actual rewards that will be distributed to the recipients given the passed total reserve
  /// @param __auctionResults The auction results to use for calculation
  /// @param _totalReserve The total reserve to use for calculation
  /// @return rewards The rewards that will be distributed.
  function computeRewardsWithTotal(AuctionResult[] calldata __auctionResults, uint256 _totalReserve) external pure returns (uint256[] memory) {
    return _computeRewards(__auctionResults, _totalReserve);
  }

  /// @notice Returns whether the given sequence has complete.
  /// @param _sequenceId The sequence to check
  /// @return True if the sequence has already completed
  function isSequenceCompleted(uint32 _sequenceId) external view returns (bool) {
    return _sequenceHasCompleted(_sequenceId);
  }

  /// @notice Returns the duration of the auction in seconds. 
  function auctionDuration() external view returns (uint64) {
    return _auctionDurationSeconds;
  }

  /// @notice Computes the reward fraction for the given auction elapsed time
  /// @param _auctionElapsedTime The elapsed time of the auction
  /// @return The reward fraction
  function computeRewardFraction(uint64 _auctionElapsedTime) external view returns (UD2x18) {
    return _fractionalReward(_auctionElapsedTime);
  }

  /// @notice Returns whether the auction is still open
  /// @return True if the , false otherwise
  function isAuctionOpen(uint32 _sequenceId, uint256 _rngCompletedAt) external view returns (bool) {
    return !(_sequenceHasCompleted(_sequenceId) || _isAuctionExpired(_rngCompletedAt));
  }

  /// @notice Returns the last completed sequence id
  function lastSequenceId() external view returns (uint32) {
    return _lastSequenceId;
  }

  /// @notice Returns the last auction result
  function getLastAuctionResult()
    external
    view
    returns (AuctionResult memory)
  {
    return _auctionResults;
  }

  /* ============ Internal Functions ============ */

  /// @notice Returns whether the auction has expired
  /// @param _rngCompletedAt The timestamp that the RNG was completed at. This is the RNG relay start time
  /// @return True if the elapsed time has exceeded the auction duration.
  function _isAuctionExpired(uint256 _rngCompletedAt) internal view returns (bool) {
    return _computeElapsed(_rngCompletedAt) > _auctionDurationSeconds;
  }

  /// @notice Computes the elapsed time since the given timestamp. If in future, then it'll be zero.
  /// @param _rngCompletedAt The timestamp that the RNG was completed at
  /// @return The time that has elapsed since the given timestamp.
  function _computeElapsed(uint256 _rngCompletedAt) internal view returns (uint256) {
    return block.timestamp < _rngCompletedAt ? 0 : block.timestamp - _rngCompletedAt;
  }

  /// @notice Computes the rewards for each reward recipient based on their reward fraction.
  /// @dev Note that the fractions compound, such that the second reward fraction is a fraction of the remained of the previous, etc.
  /// @param __auctionResults The auction results to use for calculation
  /// @param _totalReserve The total reserve to use for calculation
  /// @return The actual rewards for each reward recipient
  function _computeRewards(AuctionResult[] calldata __auctionResults, uint256 _totalReserve) internal pure returns (uint256[] memory) {
    return RewardLib.rewards(__auctionResults, _totalReserve);
  }

  /// @notice Returns whether the given sequence has completed.
  /// @param _sequenceId The sequence to check
  /// @return True if the sequence has already completed, false otherwise
  function _sequenceHasCompleted(uint32 _sequenceId) internal view returns (bool) {
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

  /// @notice Safely bounds a uint within uint96 size
  /// @param a The uint to bound
  /// @return a if a is less than or equal to uint96 max, otherwise uint96 max
  function _safeCast(uint256 a) internal pure returns (uint96) {
    return a > type(uint96).max ? type(uint96).max : uint96(a);
  }

  /**
   * @notice Requires the sender to be the rng auction relayer
   */
  modifier onlyRngAuctionRelayer() {
    if (msg.sender != rngAuctionRelayer) {
      revert UnauthorizedRelayer(msg.sender);
    }
    _;
  }

  /// @notice Requires that the sequence has not completed, and that the auction has not expired
  /// @param _sequenceId The sequence ID of the auction
  /// @param _rngCompletedAt The timestamp that the RNG was completed at
  modifier requireAuctionOpen(uint32 _sequenceId, uint256 _rngCompletedAt) {
    if (_sequenceHasCompleted(_sequenceId)) revert SequenceAlreadyCompleted();
    if (_isAuctionExpired(_rngCompletedAt)) {
      revert AuctionExpired();
    }
    _;
  }
}
