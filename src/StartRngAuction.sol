// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "owner-manager/Ownable.sol";
import { RNGInterface } from "rng/RNGInterface.sol";
import { UD2x18 } from "prb-math/UD2x18.sol";
import { UD60x18, convert } from "prb-math/UD60x18.sol";

import { RewardLib } from "local-draw-auction/libraries/RewardLib.sol";
import { IAuction, AuctionResults } from "local-draw-auction/interfaces/IAuction.sol";

/**
 * @title PoolTogether V5 StartRngAuction
 * @author Generation Software Team
 * @notice The StartRngAuction allows anyone to request a new random number using the RNG service set.
 *         The auction incetivises RNG requests to be started in-sync with prize pool draw
 *         periods across all chains.
 */
contract StartRngAuction is IAuction, Ownable {
  using SafeERC20 for IERC20;

  /* ============ Structs ============ */

  /**
   * @notice RNG Request.
   * @param id          RNG request ID
   * @param lockBlock   The block number at which the RNG service will start generating time-delayed randomness
   * @param sequenceId  Sequence ID that the RNG was requested during.
   * @param requestedAt Time at which the RNG was requested
   * @dev   The `sequenceId` value should not be assumed to be the same as a prize pool drawId even though the
   *        timing is designed to align as best as possible.
   */
  struct RngRequest {
    uint32 id;
    uint32 lockBlock;
    uint32 sequenceId;
    uint64 requestedAt;
  }

  /* ============ Variables ============ */

  /// @notice RNG instance
  RNGInterface internal _rng;

  /// @notice New RNG instance that will be applied before the next auction completion
  RNGInterface internal _pendingRng;

  /// @notice Current RNG Request
  RngRequest internal _rngRequest;

  /// @notice The last completed auction results
  AuctionResults internal _auctionResults;

  /// @notice Duration of the auction in seconds
  /// @dev This must always be less than the sequence period since the auction needs to complete each period.
  uint64 internal _auctionDurationSeconds;

  /// @notice The target time to complete the auction as a fraction of the auction duration
  UD2x18 internal _auctionTargetTimeFraction;

  /// @notice Duration of the sequence that the auction should align with
  /// @dev This must always be greater than the auction duration.
  uint64 internal _sequencePeriodSeconds;

  /**
   * @notice Offset of the sequence in seconds
   * @dev If the next sequence starts at unix timestamp `t`, then a valid offset is equal to `t % _sequencePeriodSeconds`.
   * @dev If the offset is set to some point in the future, some calculations will fail until that time, effectively
   * preventing any auctions until then.
   */
  uint64 internal _sequenceOffsetSeconds;

  /* ============ Custom Errors ============ */

  /// @notice Thrown when the auction period is zero.
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
  error AuctionDurationGteSequencePeriod(uint64 auctionDuration, uint64 sequencePeriod);

  /// @notice Thrown when the RNG address passed to the setter function is zero address.
  error RngZeroAddress();

  /// @notice Thrown if an RNG request has already been made for the current sequence.
  error RngAlreadyStarted();

  /// @notice Thrown if the time elapsed since the start of the auction is greater than the auction duration.
  error AuctionExpired();

  /* ============ Events ============ */

  /**
   * @notice Emitted when the auction duration is updated.
   * @param auctionDurationSeconds The new auction duration in seconds
   * @param auctionTargetTime The new auction target time to complete in seconds
   */
  event SetAuctionDuration(uint64 auctionDurationSeconds, uint64 auctionTargetTime);

  /**
   * @notice Emitted when the RNG service address is set.
   * @param rngService RNG service address
   */
  event RngServiceSet(RNGInterface indexed rngService);

  /* ============ Constructor ============ */

  /**
   * @notice Deploy the StartRngAuction smart contract.
   * @param rng_ Address of the RNG service
   * @param owner_ Address of the StartRngAuction owner
   * @param sequencePeriodSeconds_ Sequence period in seconds
   * @param sequenceOffsetSeconds_ Sequence offset in seconds
   * @param auctionDurationSeconds_ Auction duration in seconds
   * @param auctionTargetTime_ Target time to complete the auction in seconds
   */
  constructor(
    RNGInterface rng_,
    address owner_,
    uint64 sequencePeriodSeconds_,
    uint64 sequenceOffsetSeconds_,
    uint64 auctionDurationSeconds_,
    uint64 auctionTargetTime_
  ) Ownable(owner_) {
    if (sequencePeriodSeconds_ == 0) revert SequencePeriodZero();
    _sequencePeriodSeconds = sequencePeriodSeconds_;
    _sequenceOffsetSeconds = sequenceOffsetSeconds_;
    _setAuctionDuration(auctionDurationSeconds_, auctionTargetTime_);
    _setRngService(rng_);
  }

  /* ============ External Functions ============ */

  /**
   * @notice  Starts the RNG Request, ends the current auction, and stores the reward fraction to
   *          be allocated to the recipient.
   * @dev     Will revert if the current auction has already been completed or expired.
   * @dev     If the RNG Service requests a `feeToken` for payment, the RNG-Request-Fee is expected
   *          to be held within this contract before calling this function.
   * @dev     If there is a pending RNGInstance (see _pendingRng), it will be swapped in before the
   *          auction is completed.
   * @param _rewardRecipient Address that will receive the auction reward for starting the RNG request
   */
  function startRngRequest(address _rewardRecipient) external {
    if (address(_pendingRng) != address(_rng)) {
      _rng = _pendingRng;
    }

    if (_isRngRequested()) revert RngAlreadyStarted();

    uint64 _elapsedTimeSeconds = _elapsedTime();
    if (_elapsedTimeSeconds > _auctionDurationSeconds) revert AuctionExpired();

    (address _feeToken, uint256 _requestFee) = _rng.getRequestFee();
    if (_feeToken != address(0) && _requestFee > 0) {
      if (IERC20(_feeToken).balanceOf(address(this)) < _requestFee) {
        // Transfer tokens from caller to this contract before continuing
        IERC20(_feeToken).transferFrom(msg.sender, address(this), _requestFee);
      }
      // Increase allowance for the RNG service to take the request fee
      IERC20(_feeToken).safeIncreaseAllowance(address(_rng), _requestFee);
    }

    (uint32 _rngRequestId, uint32 _lockBlock) = _rng.requestRandomNumber();
    _rngRequest.id = _rngRequestId;
    _rngRequest.lockBlock = _lockBlock;
    _rngRequest.sequenceId = _currentSequenceId();
    _rngRequest.requestedAt = _currentTime();

    UD2x18 _rewardFraction = _currentFractionalReward();
    _auctionResults.recipient = _rewardRecipient;
    _auctionResults.rewardFraction = _rewardFraction;

    emit AuctionCompleted(
      _rewardRecipient,
      _rngRequest.sequenceId,
      _elapsedTimeSeconds,
      _rewardFraction
    );
  }

  /* ============ State Functions ============ */

  /**
   * @inheritdoc IAuction
   * @dev The auction is complete when the RNG has been requested for the current sequence.
   */
  function isAuctionComplete() external view returns (bool) {
    return _isRngRequested();
  }

  /**
   * @inheritdoc IAuction
   * @dev The auction is open if RNG has not been requested yet this sequence and the
   * auction has not expired.
   */
  function isAuctionOpen() external view returns (bool) {
    return !_isRngRequested() && _elapsedTime() <= _auctionDurationSeconds;
  }

  /**
   * @inheritdoc IAuction
   */
  function elapsedTime() external view returns (uint64) {
    return _elapsedTime();
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
  function currentFractionalReward() external view returns (UD2x18) {
    return _currentFractionalReward();
  }

  /**
   * @inheritdoc IAuction
   */
  function currentRewardAmount(uint256 _reserve) external view returns (uint256) {
    AuctionResults memory _results = AuctionResults(msg.sender, _currentFractionalReward());
    return RewardLib.reward(_results, _reserve);
  }

  /**
   * @inheritdoc IAuction
   */
  function getAuctionResults()
    external
    view
    returns (AuctionResults memory auctionResults, uint32 sequenceId)
  {
    return (_auctionResults, _rngRequest.sequenceId);
  }

  /**
   * @notice Calculates a unique identifier for the current sequence.
   * @return The current sequence ID.
   */
  function currentSequenceId() external view returns (uint32) {
    return _currentSequenceId();
  }

  /**
   * @notice Returns whether the RNG request has completed or not for the current sequence.
   * @return True if the RNG request has completed, false otherwise.
   */
  function isRngComplete() external view returns (bool) {
    return _isRngComplete();
  }

  /**
   * @notice Returns the completion time of the current RNG request.
   * @return RNG request completion time in seconds
   */
  function rngCompletedAt() external view returns (uint64) {
    return _rng.completedAt(_rngRequest.id);
  }

  /**
   * @notice Returns the result of the last RNG Request.
   * @dev The RNG service may revert if the current RNG request is not complete.
   * @dev Not marked as view since RNGInterface.randomNumber is not a view function.
   * @return rngRequest_ The RNG request
   * @return randomNumber_ The random number result
   * @return rngCompletedAt_ The timestamp at which the random number request was completed
   */
  function getRngResults()
    external
    returns (RngRequest memory rngRequest_, uint256 randomNumber_, uint64 rngCompletedAt_)
  {
    return (_rngRequest, _rng.randomNumber(_rngRequest.id), _rng.completedAt(_rngRequest.id));
  }

  /* ============ Getter Functions ============ */

  /**
   * @notice Returns the current RNG request.
   * @return The RNG request
   */
  function getRngRequest() external view returns (RngRequest memory) {
    return _rngRequest;
  }

  /**
   * @notice Returns the RNG service used to generate random numbers.
   * @return RNG service instance
   */
  function getRngService() external view returns (RNGInterface) {
    return _rng;
  }

  /**
   * @notice Returns the pending RNG service that will replace the current service before the next auction completes.
   * @return RNG service instance
   */
  function getPendingRngService() external view returns (RNGInterface) {
    return _pendingRng;
  }

  /**
   * @notice Returns the sequence offset.
   * @return The sequence offset in seconds
   */
  function getSequenceOffset() external view returns (uint64) {
    return _sequenceOffsetSeconds;
  }

  /**
   * @notice Returns the sequence period.
   * @return The sequence period in seconds
   */
  function getSequencePeriod() external view returns (uint64) {
    return _sequencePeriodSeconds;
  }

  /* ============ Setters ============ */

  /**
   * @notice Sets the RNG service used to generate random numbers.
   * @dev Only callable by the owner.
   * @dev The service will not be udpated immediately so the current auction is not disturbed. Instead,
   * it will be swapped out right before the next auction is completed.
   * @param _rngService Address of the new RNG service
   */
  function setRngService(RNGInterface _rngService) external onlyOwner {
    _setRngService(_rngService);
  }

  /**
   * @notice Sets the auction duration and target completion time
   * @param auctionDurationSeconds_ The new auction duration in seconds
   * @param auctionTargetTime_ The new auction target completion time in seconds
   * @dev The target completion time must be greater than zero and less than the auction duration.
   */
  function setAuctionDuration(
    uint64 auctionDurationSeconds_,
    uint64 auctionTargetTime_
  ) external onlyOwner {
    _setAuctionDuration(auctionDurationSeconds_, auctionTargetTime_);
  }

  /* ============ Internal Functions ============ */

  /**
   * @notice Returns the current timestamp.
   * @return The current timestamp.
   */
  function _currentTime() internal view returns (uint64) {
    return uint64(block.timestamp);
  }

  /**
   * @notice Calculates a unique identifier for the current sequence.
   * @return The current sequence ID.
   */
  function _currentSequenceId() internal view returns (uint32) {
    /**
     * Use integer division to calculate a unique ID based off the current timestamp that will remain the same
     * throughout the entire sequence.
     */
    return uint32((_currentTime() - _sequenceOffsetSeconds) / _sequencePeriodSeconds);
  }

  /**
   * @notice Calculates the elapsed time for the current RNG auction.
   * @return The elapsed time since the start of the current RNG auction in seconds.
   */
  function _elapsedTime() internal view returns (uint64) {
    return (_currentTime() - _sequenceOffsetSeconds) % _sequencePeriodSeconds;
  }

  /**
   * @notice Calculates the reward fraction for the current auction if it were to be completed at this time.
   * @dev Uses the last sold fraction as the target price for this auction.
   * @return The current reward fraction as a UD2x18 value
   */
  function _currentFractionalReward() internal view returns (UD2x18) {
    return
      RewardLib.fractionalReward(
        _elapsedTime(),
        _auctionDurationSeconds,
        _auctionTargetTimeFraction,
        _auctionResults.rewardFraction
      );
  }

  /**
   * @notice Returns whether the RNG request has been started for the current sequence.
   * @return True if the RNG request has been started, false otherwise.
   */
  function _isRngRequested() internal view returns (bool) {
    return _rngRequest.sequenceId == _currentSequenceId();
  }

  /**
   * @notice Returns whether the RNG request has completed or not for the current sequence ID.
   * @return True if the RNG request has completed, false otherwise.
   */
  function _isRngComplete() internal view returns (bool) {
    return _isRngRequested() && _rng.isRequestComplete(_rngRequest.id);
  }

  /**
   * @notice Sets the RNG service used to generate random numbers.
   * @param _newRng Address of the new RNG service
   */
  function _setRngService(RNGInterface _newRng) internal {
    if (address(_newRng) == address(0)) revert RngZeroAddress();

    // Set as pending if RNG is being replaced.
    // The RNG will be swapped with the pending one before the next random number is requested.
    _pendingRng = _newRng;
    if (address(_rng) == address(0)) {
      // Set immediately if no RNG is set.
      _rng = _newRng;
    }

    emit RngServiceSet(_newRng);
  }

  /**
   * @notice Sets the auction duration
   * @param auctionDurationSeconds_ The new auction duration in seconds
   * @param _auctionTargetTime The new auction target time to complete in seconds
   */
  function _setAuctionDuration(uint64 auctionDurationSeconds_, uint64 _auctionTargetTime) internal {
    if (auctionDurationSeconds_ == 0) revert AuctionDurationZero();
    if (_auctionTargetTime == 0) revert AuctionTargetTimeZero();
    if (auctionDurationSeconds_ >= _sequencePeriodSeconds) {
      revert AuctionDurationGteSequencePeriod(auctionDurationSeconds_, _sequencePeriodSeconds);
    }
    if (_auctionTargetTime > auctionDurationSeconds_) {
      revert AuctionTargetTimeExceedsDuration(_auctionTargetTime, auctionDurationSeconds_);
    }
    _auctionDurationSeconds = auctionDurationSeconds_;
    _auctionTargetTimeFraction = UD2x18.wrap(
      uint64(convert(_auctionTargetTime).div(convert(_auctionDurationSeconds)).unwrap())
    );
    emit SetAuctionDuration(_auctionDurationSeconds, _auctionTargetTime);
  }
}
