// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "owner-manager/Ownable.sol";
import { RNGInterface } from "rng/RNGInterface.sol";
import { UD2x18 } from "prb-math/UD2x18.sol";
import { UD60x18, toUD60x18, fromUD60x18 } from "prb-math/UD60x18.sol";

import { RewardLib } from "local-draw-auction/libraries/RewardLib.sol";
import { PhaseManager } from "local-draw-auction/abstract/PhaseManager.sol";
import { IAuction } from "local-draw-auction/interfaces/IAuction.sol";

/**
 * @title PoolTogether V5 RngAuction
 * @author Generation Software Team
 * @notice The RngAuction allows anyone to request a new random number using the RNG service set.
 *         The auction incetivises RNG requests to be started in-sync with prize pool draw
 *         periods across all chains.
 */
contract RngAuction is PhaseManager, Ownable, IAuction {
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

  /// @notice Current RNG Request
  RngRequest internal _rngRequest;

  /// @notice Duration of the auction in seconds
  /// @dev This will always be less than the sequence since the auction needs to complete each period.
  uint64 internal _auctionDurationSeconds;

  /// @notice Duration of the sequence that the auction should align with
  /// @dev This will always be greater than the auction duration.
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

  /// @notice Thrown if the RNG request is not complete for the current sequence.
  error RngNotCompleted();

  /// @notice Thrown if the time elapsed since the start of the auction is greater than the auction duration.
  error AuctionExpired();

  /* ============ Events ============ */

  /**
   * @notice Emitted when the auction duration is updated.
   * @param auctionDurationSeconds The new auction duration in seconds
   */
  event SetAuctionDuration(uint64 auctionDurationSeconds);

  /**
   * @notice Emitted when the RNG auction is completed.
   * @param rewardRecipient The address that will receive the reward
   * @param sequenceId The sequence ID of the auction
   * @param rngRequestId ID of the RNG request
   * @param rewardPortion The portion of the available reserves that will be rewarded
   */
  event RngAuctionCompleted(
    address indexed rewardRecipient,
    uint32 indexed sequenceId,
    uint32 indexed rngRequestId,
    UD2x18 rewardPortion
  );

  /**
   * @notice Emitted when the RNG service address is set.
   * @param rngService RNG service address
   */
  event RngServiceSet(RNGInterface indexed rngService);

  /* ============ Constructor ============ */

  /**
   * @notice Deploy the RngAuction smart contract.
   * @param rng_ Address of the RNG service
   * @param owner_ Address of the RngAuction owner
   * @param sequencePeriodSeconds_ Sequence period in seconds
   * @param sequenceOffsetSeconds_ Sequence offset in seconds
   * @param auctionDurationSeconds_ Auction duration in seconds
   */
  constructor(
    RNGInterface rng_,
    address owner_,
    uint64 sequencePeriodSeconds_,
    uint64 sequenceOffsetSeconds_,
    uint64 auctionDurationSeconds_
  ) PhaseManager() Ownable(owner_) {
    if (sequencePeriodSeconds_ == 0) revert SequencePeriodZero();
    _sequencePeriodSeconds = sequencePeriodSeconds_;
    _sequenceOffsetSeconds = sequenceOffsetSeconds_;
    _setAuctionDuration(auctionDurationSeconds_);
    _setRngService(rng_);
  }

  /* ============ External Functions ============ */

  /**
   * @inheritdoc IAuction
   * @notice  Starts the RNG Request, ends the current auction, and stores the reward portion to
   *          be allocated to the recipient.
   * @dev     Will revert if the current auction has already been completed or expired.
   * @dev     If the RNG Service requests a `feeToken` for payment, the RNG-Request-Fee is expected
   *          to be held within this contract before calling this function.
   * @param _rewardRecipient Address that will receive the auction reward for starting the RNG request
   */
  function completeAuction(address _rewardRecipient) external {
    if (_isRngRequested()) revert RngAlreadyStarted();
    if (_elapsedTime() > _auctionDurationSeconds) revert AuctionExpired();

    (address _feeToken, uint256 _requestFee) = _rng.getRequestFee();

    if (_feeToken != address(0) && _requestFee > 0) {
      IERC20(_feeToken).safeIncreaseAllowance(address(_rng), _requestFee);
    }

    (uint32 _rngRequestId, uint32 _lockBlock) = _rng.requestRandomNumber();
    _rngRequest.id = _rngRequestId;
    _rngRequest.lockBlock = _lockBlock;
    _rngRequest.sequenceId = _currentSequenceId();
    _rngRequest.requestedAt = _currentTime();

    UD2x18 _rewardPortion = _currentRewardPortion();
    _setPhase(_rewardPortion, _rewardRecipient);

    emit RngAuctionCompleted(
      _rewardRecipient,
      _rngRequest.sequenceId,
      _rngRequestId,
      _rewardPortion
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
  function currentRewardPortion() external view returns (UD2x18) {
    return _currentRewardPortion();
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
   * @notice Returns the random number for the RNG request.
   * @return The random number provided by the RNG service
   */
  function randomNumber() external returns (uint256) {
    return _rng.randomNumber(_rngRequest.id);
  }

  /**
   * @notice Returns the result of the last completed auction.
   * @dev Reverts if the current RNG request is not complete.
   * @return rngRequest The RNG request
   * @return rngCompletedAt The timestamp at which the random number request was completed
   */
  function getResults()
    external
    view
    returns (RngRequest memory rngRequest, uint64 rngCompletedAt)
  {
    if (!_isRngComplete()) revert RngNotCompleted();
    return (_rngRequest, _rng.completedAt(_rngRequest.id));
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
   * @dev Will revert if an RNG request is in progress (if the auction is open, then there is no active RNG request).
   * @param _rngService Address of the new RNG service
   */
  function setRngService(RNGInterface _rngService) external onlyOwner {
    _setRngService(_rngService);
  }

  /**
   * @notice Sets the auction duration
   * @param auctionDurationSeconds_ The new auction duration in seconds
   */
  function setAuctionDuration(uint64 auctionDurationSeconds_) external onlyOwner {
    _setAuctionDuration(auctionDurationSeconds_);
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
   * @notice Calculates the reward portion for the current auction if it were to be completed at this time.
   * @return The current reward portion as a UD2x18 value
   */
  function _currentRewardPortion() internal view returns (UD2x18) {
    return RewardLib.rewardPortion(_elapsedTime(), _auctionDurationSeconds);
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
   * @param rng_ Address of the new RNG service
   */
  function _setRngService(RNGInterface rng_) internal {
    if (address(rng_) == address(0)) revert RngZeroAddress();
    _rng = rng_;
    emit RngServiceSet(rng_);
  }

  /**
   * @notice Sets the auction duration
   * @param auctionDurationSeconds_ The new auction duration in seconds
   */
  function _setAuctionDuration(uint64 auctionDurationSeconds_) internal {
    if (auctionDurationSeconds_ == 0) revert AuctionDurationZero();
    if (auctionDurationSeconds_ >= _sequencePeriodSeconds)
      revert AuctionDurationGteSequencePeriod(auctionDurationSeconds_, _sequencePeriodSeconds);
    _auctionDurationSeconds = auctionDurationSeconds_;
    emit SetAuctionDuration(_auctionDurationSeconds);
  }
}
