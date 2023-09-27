// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "owner-manager/Ownable.sol";
import { RNGInterface } from "rng/RNGInterface.sol";
import { UD2x18 } from "prb-math/UD2x18.sol";
import { UD60x18, convert, intoUD2x18 } from "prb-math/UD60x18.sol";

import { RewardLib } from "./libraries/RewardLib.sol";
import { IAuction, AuctionResult } from "./interfaces/IAuction.sol";

/**
 * @notice The results of a successful RNG auction.
 * @param recipient The recipient of the auction reward
 * @param rewardFraction The reward fraction that the user will receive
 * @param sequenceId The id of the sequence that this auction belonged to
 * @param rng The RNG service that was used to generate the random number
 * @param rngRequestId The id of the RNG request that was made
 * @dev   The `sequenceId` value should not be assumed to be the same as a prize pool drawId, but the sequence and offset should match the prize pool.
 */
struct RngAuctionResult {
  address recipient;
  UD2x18 rewardFraction;
  uint32 sequenceId;
  RNGInterface rng;
  uint32 rngRequestId;
}

/* ============ Custom Errors ============ */

/// @notice Thrown when the auction duration is zero.
error AuctionDurationZero();

/// @notice Thrown if the auction target time is zero.
error AuctionTargetTimeZero();

/**
 * @notice Thrown if the auction target time exceeds the auction duration.
 * @param auctionTargetTime The auction target time to complete in seconds
 * @param auctionDuration The auction duration in seconds
 */
error AuctionTargetTimeExceedsDuration(uint64 auctionTargetTime, uint64 auctionDuration);

/// @notice Thrown when the sequence period is zero.
error SequencePeriodZero();

/**
 * @notice Thrown when the auction duration is greater than or equal to the sequence.
 * @param auctionDuration The auction duration in seconds
 * @param sequencePeriod The sequence period in seconds
 */
error AuctionDurationGtSequencePeriod(uint64 auctionDuration, uint64 sequencePeriod);

/// @notice Thrown when the RNG address passed to the setter function is zero address.
error RngZeroAddress();

/// @notice Thrown if the next sequence cannot yet be started
error CannotStartNextSequence();

/// @notice Thrown if the time elapsed since the start of the auction is greater than the auction duration.
error AuctionExpired();

/// @notice Thrown if owner set is the zero address.
error OwnerZeroAddress();

/// @notice Emitted when the zero address is passed as reward recipient
error RewardRecipientIsZero();

/**
 * @title PoolTogether V5 RngAuction
 * @author G9 Software Inc.
 * @notice The RngAuction allows anyone to request a new random number using the RNG service set.
 *         The auction incentivises RNG requests to be started in-sync with prize pool draw
 *         periods across all chains.
 */
contract RngAuction is IAuction, Ownable {
  using SafeERC20 for IERC20;

  /* ============ Variables ============ */

  /// @notice Duration of the auction in seconds
  /// @dev This must always be less than the sequence period since the auction needs to complete each period.
  uint64 public immutable auctionDuration;

  /// @notice The target time to complete the auction in seconds
  uint64 public immutable auctionTargetTime;

  /// @notice The target time to complete the auction as a fraction of the auction duration
  UD2x18 internal immutable _auctionTargetTimeFraction;

  /// @notice Target reward fraction to complete the first auction.
  UD2x18 internal immutable _firstAuctionTargetRewardFraction;

  /// @notice Duration of the sequence that the auction should align with
  /// @dev This must always be greater than the auction duration.
  uint64 public immutable sequencePeriod;

  /**
   * @notice Offset of the sequence in seconds
   * @dev If the next sequence starts at unix timestamp `t`, then a valid offset is equal to `t % sequencePeriod`.
   * @dev If the offset is set to some point in the future, some calculations will fail until that time, effectively
   * preventing any auctions until then.
   */
  uint64 public immutable sequenceOffset;

  /// @notice New RNG instance that will be applied before the next auction completion
  RNGInterface internal _nextRng;

  /// @notice The last auction result
  RngAuctionResult internal _lastAuction;

  /* ============ Events ============ */

  /**
   * @notice Emitted when the RNG service address is set.
   * @param rngService RNG service address
   */
  event SetNextRngService(RNGInterface indexed rngService);

  /**
   * @notice Emitted when the auction is completed.
   * @param recipient The recipient of the auction reward
   * @param sequenceId The sequence ID for the auction
   * @param rng The RNGInterface that was used for this auction
   * @param rngRequestId The RNGInterface request ID
   * @param elapsedTime The amount of time that the auction ran for in seconds
   * @param rewardFraction The fraction of the available rewards to be allocated to the recipient
   */
  event RngAuctionCompleted(
    address indexed sender,
    address indexed recipient,
    uint32 indexed sequenceId,
    RNGInterface rng,
    uint32 rngRequestId,
    uint64 elapsedTime,
    UD2x18 rewardFraction
  );

  /* ============ Constructor ============ */

  /**
   * @notice Deploy the RngAuction smart contract.
   * @param rng_ Address of the RNG service
   * @param owner_ Address of the RngAuction owner. The owner may swap out the RNG service.
   * @param sequencePeriod_ Sequence period in seconds
   * @param sequenceOffset_ Sequence offset in seconds
   * @param auctionDurationSeconds_ Auction duration in seconds
   * @param auctionTargetTime_ Target time to complete the auction in seconds
   * @param firstAuctionTargetRewardFraction_ Target reward fraction to complete the first auction
   */
  constructor(
    RNGInterface rng_,
    address owner_,
    uint64 sequencePeriod_,
    uint64 sequenceOffset_,
    uint64 auctionDurationSeconds_,
    uint64 auctionTargetTime_,
    UD2x18 firstAuctionTargetRewardFraction_
  ) Ownable(owner_) {
    if (address(0) == owner_) revert OwnerZeroAddress();
    if (sequencePeriod_ == 0) revert SequencePeriodZero();
    if (auctionTargetTime_ > auctionDurationSeconds_) {
      revert AuctionTargetTimeExceedsDuration(
        uint64(auctionTargetTime_),
        uint64(auctionDurationSeconds_)
      );
    }

    if (auctionDurationSeconds_ > sequencePeriod_)
      revert AuctionDurationGtSequencePeriod(
        uint64(auctionDurationSeconds_),
        uint64(sequencePeriod_)
      );

    sequencePeriod = sequencePeriod_;
    sequenceOffset = sequenceOffset_;
    auctionDuration = auctionDurationSeconds_;
    auctionTargetTime = auctionTargetTime_;
    _auctionTargetTimeFraction = (
      intoUD2x18(
        convert(uint256(auctionTargetTime_)).div(convert(uint256(auctionDurationSeconds_)))
      )
    );

    _firstAuctionTargetRewardFraction = firstAuctionTargetRewardFraction_;

    _setNextRngService(rng_);
  }

  /* ============ External Functions ============ */

  /**
   * @notice  Starts the RNG Request, ends the current auction, and stores the reward fraction to
   *          be allocated to the recipient.
   * @dev     Will revert if the current auction has already been completed or expired.
   * @dev     If the RNG service expects the fee to already be in possession, the caller should not
   *          call this function directly and should instead call a helper function that transfers
   *          the funds to the RNG service before calling this function.
   * @dev     If there is a pending RNG service (see _nextRng), it will be swapped in before the
   *          auction is completed.
   * @param _rewardRecipient Address that will be allocated the auction reward for starting the RNG request.
   * The recipient can withdraw the rewards from the Prize Pools that use the random number once all
   * subsequent auctions are complete.
   */
  function startRngRequest(address _rewardRecipient) external {
    if (_rewardRecipient == address(0)) revert RewardRecipientIsZero();
    if (!_canStartNextSequence()) revert CannotStartNextSequence();

    RNGInterface rng = _nextRng;

    uint64 _auctionElapsedTimeSeconds = _auctionElapsedTime();
    if (_auctionElapsedTimeSeconds > auctionDuration) revert AuctionExpired();

    (address _feeToken, uint256 _requestFee) = rng.getRequestFee();
    if (
      _feeToken != address(0) &&
      _requestFee > 0 &&
      IERC20(_feeToken).allowance(address(this), address(rng)) < _requestFee
    ) {
      /**
       * Set approval for the RNG service to take the request fee to support RNG services
       * that pull funds from the caller.
       * NOTE: Not compatible with safeApprove or safeIncreaseAllowance.
       */
      IERC20(_feeToken).approve(address(rng), _requestFee);
    }

    (uint32 rngRequestId, ) = rng.requestRandomNumber();
    uint32 sequenceId = _openSequenceId();
    UD2x18 rewardFraction = _currentFractionalReward();

    _lastAuction = RngAuctionResult({
      recipient: _rewardRecipient,
      rewardFraction: rewardFraction,
      sequenceId: sequenceId,
      rng: rng,
      rngRequestId: rngRequestId
    });

    emit RngAuctionCompleted(
      msg.sender,
      _rewardRecipient,
      sequenceId,
      rng,
      rngRequestId,
      _auctionElapsedTimeSeconds,
      rewardFraction
    );
  }

  /* ============ State Functions ============ */

  /**
   * @notice Returns whether the RNG request has been started for the current sequence.
   * @dev The auction is complete when the RNG has been requested for the current sequence.
   * @return True if the RNG request has been started, false otherwise.
   */
  function canStartNextSequence() external view returns (bool) {
    return _canStartNextSequence();
  }

  /**
   * @notice Checks if the auction is still open and if it can be completed.
   * @dev The auction is open if RNG has not been requested yet this sequence and the
   * auction has not expired.
   * @return True if the auction is open and can be completed, false otherwise.
   */
  function isAuctionOpen() external view returns (bool) {
    return _canStartNextSequence() && _auctionElapsedTime() <= auctionDuration;
  }

  /**
   * @notice The amount of time remaining in the current open auction
   * @return The elapsed time since the auction started in seconds
   */
  function auctionElapsedTime() external view returns (uint64) {
    return _auctionElapsedTime();
  }

  /**
   * @notice Calculates the reward fraction for the current auction if it were to be completed at this time.
   * @dev Uses the last sold fraction as the target price for this auction.
   * @return The current reward fraction as a UD2x18 value
   */
  function currentFractionalReward() external view returns (UD2x18) {
    return _currentFractionalReward();
  }

  /**
   * @notice The last auction results.
   * @return RngAuctionResults struct from the last auction.
   */
  function getLastAuction() external view returns (RngAuctionResult memory) {
    return _lastAuction;
  }

  /**
   * @notice Returns the last auction as an AuctionResult struct to be used to calculate rewards.
   * @return AuctionResult struct with data from the last auction
   */
  function getLastAuctionResult() external view returns (AuctionResult memory) {
    return
      AuctionResult({
        recipient: _lastAuction.recipient,
        rewardFraction: _lastAuction.rewardFraction
      });
  }

  /**
   * @notice Calculates a unique identifier for the current sequence.
   * @return The current sequence ID.
   */
  function openSequenceId() external view returns (uint32) {
    return _openSequenceId();
  }

  /**
   * @notice Returns the sequence ID from the last auction.
   * @return The last sequence ID.
   */
  function lastSequenceId() external view returns (uint32) {
    return _lastAuction.sequenceId;
  }

  /**
   * @notice Returns whether the RNG request has completed or not for the current sequence.
   * @return True if the RNG request has completed, false otherwise.
   */
  function isRngComplete() external view returns (bool) {
    RNGInterface rng = _lastAuction.rng;
    uint32 requestId = _lastAuction.rngRequestId;
    return !_canStartNextSequence() && rng.isRequestComplete(requestId);
  }

  /**
   * @notice Returns the result of the last RNG Request.
   * @dev The RNG service may revert if the current RNG request is not complete.
   * @dev Not marked as view since RNGInterface.randomNumber is not a view function.
   * @return randomNumber The random number result
   * @return rngCompletedAt The timestamp at which the random number request was completed
   */
  function getRngResults() external returns (uint256 randomNumber, uint64 rngCompletedAt) {
    RNGInterface rng = _lastAuction.rng;
    uint32 requestId = _lastAuction.rngRequestId;
    randomNumber = rng.randomNumber(requestId);
    rngCompletedAt = rng.completedAt(requestId);
  }

  /// @notice Computes the reward fraction for the given auction elapsed time.
  /// @param __auctionElapsedTime The elapsed time of the auction in seconds
  /// @return The reward fraction as a UD2x18 value
  function computeRewardFraction(uint64 __auctionElapsedTime) external view returns (UD2x18) {
    return _computeRewardFraction(__auctionElapsedTime);
  }

  /* ============ Getter Functions ============ */

  /**
   * @notice Returns the RNG service used to generate random numbers.
   * @return RNG service instance
   */
  function getLastRngService() external view returns (RNGInterface) {
    return _lastAuction.rng;
  }

  /**
   * @notice Returns the pending RNG service that will replace the current service before the next auction completes.
   * @return RNG service instance
   */
  function getNextRngService() external view returns (RNGInterface) {
    return _nextRng;
  }

  /* ============ Setters ============ */

  /**
   * @notice Sets the RNG service used to generate random numbers.
   * @dev Only callable by the owner.
   * @dev The service will not be updated immediately so the current auction is not disturbed. Instead,
   * it will be swapped out right before the next auction is completed.
   * @param _rngService Address of the new RNG service
   */
  function setNextRngService(RNGInterface _rngService) external onlyOwner {
    _setNextRngService(_rngService);
  }

  /* ============ Internal Functions ============ */

  /**
   * @notice Calculates a unique identifier for the current sequence.
   * @return The current sequence ID.
   */
  function _openSequenceId() internal view returns (uint32) {
    /**
     * Use integer division to calculate a unique ID based off the current timestamp that will remain the same
     * throughout the entire sequence.
     */
    uint64 currentTime = uint64(block.timestamp);
    if (currentTime < sequenceOffset) {
      return 0;
    }
    return uint32((currentTime - sequenceOffset) / sequencePeriod);
  }

  /**
   * @notice Calculates the elapsed time for the current RNG auction.
   * @return The elapsed time since the start of the current RNG auction in seconds.
   */
  function _auctionElapsedTime() internal view returns (uint64) {
    uint64 currentTime = uint64(block.timestamp);
    if (currentTime < sequenceOffset) {
      return 0;
    }
    return (uint64(block.timestamp) - sequenceOffset) % sequencePeriod;
  }

  /**
   * @notice Calculates the reward fraction for the current auction if it were to be completed at this time.
   * @dev Uses the last sold fraction as the target price for this auction.
   * @return The current reward fraction as a UD2x18 value
   */
  function _currentFractionalReward() internal view returns (UD2x18) {
    return _computeRewardFraction(_auctionElapsedTime());
  }

  /**
   * @notice Calculates the reward fraction for the current auction based on the given elapsed time.
   * @param __auctionElapsedTime The elapsed time of the auction in seconds
   * @dev Uses the last sold fraction as the target price for this auction.
   * @return The current reward fraction as a UD2x18 value
   */
  function _computeRewardFraction(uint64 __auctionElapsedTime) internal view returns (UD2x18) {
    return
      RewardLib.fractionalReward(
        __auctionElapsedTime,
        auctionDuration,
        _auctionTargetTimeFraction,
        _lastAuction.sequenceId == 0
          ? _firstAuctionTargetRewardFraction
          : _lastAuction.rewardFraction
      );
  }

  /**
   * @notice Returns whether the RNG request has been started for the current sequence.
   * @dev The auction is complete when the RNG has been requested for the current sequence.
   * @return True if the RNG request has been started, false otherwise.
   */
  function _canStartNextSequence() internal view returns (bool) {
    return _lastAuction.sequenceId != _openSequenceId();
  }

  /**
   * @notice Sets the RNG service used to generate random numbers.
   * @param _newRng Address of the new RNG service
   */
  function _setNextRngService(RNGInterface _newRng) internal {
    if (address(_newRng) == address(0)) revert RngZeroAddress();

    // Set as pending if RNG is being replaced.
    // The RNG will be swapped with the pending one before the next random number is requested.
    _nextRng = _newRng;

    emit SetNextRngService(_newRng);
  }
}
