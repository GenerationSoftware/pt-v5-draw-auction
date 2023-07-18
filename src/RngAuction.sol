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

/**
 * @title PoolTogether V5 RngAuction
 * @author Generation Software Team
 * @notice The RngAuction allows anyone to request a new random number using the RNG service set.
 *         The auction is a single phase that incetivises RNG requests to be started in-sync with
 *         prize pool draw periods across all chains. DrawAuction contracts per-chain will then
 *         auction off the remaining phases to complete the active draw and bridge the random
 *         number along with the auction information.
 */
contract RngAuction is PhaseManager, Ownable {
  using SafeERC20 for IERC20;

  /* ============ Structs ============ */

  /**
   * @notice RNG Request.
   * @param id          RNG request ID
   * @param lockBlock   The block number at which the RNG service will start generating time-delayed randomness
   * @param drawWindow  Draw window identifier that the RNG was requested during.
   * @param requestedAt Time at which the RNG was requested
   * @dev   The `drawWindow` value should not be assumed to be the same as a prize pool drawId even though the
   *        timing of the auctions are designed to align as best as possible.
   */
  struct RngRequest {
    uint32 id;
    uint32 lockBlock;
    uint32 drawWindow;
    uint64 requestedAt;
  }

  /* ============ Variables ============ */

  /// @notice RNG instance
  RNGInterface internal _rng;

  /// @notice Current RNG Request
  RngRequest internal _rngRequest;

  /// @notice Duration of the auction in seconds
  /// @dev This will always be less than the draw period since the auction needs to complete each period.
  uint64 internal _auctionDurationSeconds;

  /// @notice Duration of the draw period that the auction should align with
  /// @dev This will always be greater than the auction duration.
  uint64 internal _drawPeriodSeconds;

  /**
   * @notice Offset of the draw period in seconds
   * @dev If the next draw period starts at unix timestamp `t`, then a valid offset is equal to `t % _drawPeriodSeconds`.
   * @dev If the offset is set to some point in the future, some calculations will fail until that time, effectively
   * preventing any auctions until then.
   */
  uint64 internal _drawPeriodOffset;

  /// @notice Identifier of the last draw window that had a completed RNG auction
  /// @dev This value may not align with prize pool draw IDs.
  uint32 internal _lastAuctionedDrawWindow;

  /* ============ Custom Errors ============ */

  /// @notice Thrown when the auction period is zero.
  error AuctionDurationZero();

  /// @notice Thrown when the draw period is zero.
  error DrawPeriodZero();

  /**
   * @notice Thrown when the auction duration is greater than or equal to the draw period.
   * @param auctionDuration The auction duration in seconds
   * @param drawPeriod The draw period in seconds
   */
  error AuctionDurationGteDrawPeriod(uint64 auctionDuration, uint64 drawPeriod);

  /// @notice Thrown when the RNG address passed to the setter function is zero address.
  error RngZeroAddress();

  /// @notice Thrown if an RNG request has already been made for the current draw period.
  error RngAlreadyStarted();

  /// @notice Thrown if the RNG auction duration has completely elapsed for the current draw period.
  error RngAuctionExpired();

  /* ============ Events ============ */

  /**
   * @notice Emitted when the auction duration is updated.
   * @param auctionDurationSeconds The new auction duration in seconds
   */
  event SetAuctionDuration(uint64 auctionDurationSeconds);

  /**
   * @notice Emitted when the RNG auction is completed.
   * @param completedBy The address that completed the RNG auction
   * @param rewardRecipient The address that will receive the reward
   * @param rngRequestId ID of the RNG request
   * @param rewardPortion The portion of the available reserves that will be rewarded
   */
  event RngAuctionCompleted(
    address indexed completedBy,
    address indexed rewardRecipient,
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
   * @param drawPeriodSeconds_ Draw period in seconds
   * @param drawPeriodOffset_ Draw period offset in seconds
   * @param auctionDurationSeconds_ Auction duration in seconds
   */
  constructor(
    RNGInterface rng_,
    address owner_,
    uint64 drawPeriodSeconds_,
    uint64 drawPeriodOffset_,
    uint64 auctionDurationSeconds_
  ) PhaseManager(1) Ownable(owner_) {
    if (drawPeriodSeconds_ == 0) revert DrawPeriodZero();
    _drawPeriodSeconds = drawPeriodSeconds_;
    _drawPeriodOffset = drawPeriodOffset_;
    _setAuctionDuration(auctionDurationSeconds_);
    _setRngService(rng_);
  }

  /* ============ Modifiers ============ */

  /// @notice Reverts if an RNG request has been started for the current draw period.
  modifier requireRngNotRequested() {
    if (_isRngRequested()) revert RngAlreadyStarted();
    _;
  }

  /* ============ External Functions ============ */

  /**
   * @notice  Starts the RNG Request, ends the current auction, and stores the reward portion to
   *          be allocated to the recipient.
   * @dev     Will revert if the current RNG auction has already been closed or elapsed.
   * @dev     If the RNG Service request a `feeToken` for payment, the RNG-Request-Fee is expected
   *          to be held within this contract before calling this function.
   * @param _rewardRecipient Address that will receive the auction reward for starting the RNG request
   */
  function startRngRequest(address _rewardRecipient) external requireRngNotRequested {
    // Calculate the elapsed auction time by taking the remainder of the current time over the draw period.
    uint64 _auctionElapsedSeconds = _rngAuctionElapsedTime();
    if (_auctionElapsedSeconds > _auctionDurationSeconds) revert RngAuctionExpired();

    (address _feeToken, uint256 _requestFee) = _rng.getRequestFee();

    if (_feeToken != address(0) && _requestFee > 0) {
      IERC20(_feeToken).safeIncreaseAllowance(address(_rng), _requestFee);
    }

    (uint32 _requestId, uint32 _lockBlock) = _rng.requestRandomNumber();
    _rngRequest.id = _requestId;
    _rngRequest.lockBlock = _lockBlock;
    _rngRequest.drawWindow = _currentDrawWindow();
    _rngRequest.requestedAt = _currentTime();

    UD2x18 _rewardPortion = RewardLib.rewardPortion(
      _auctionElapsedSeconds,
      _auctionDurationSeconds
    );
    _setPhase(0, _rewardPortion, _rewardRecipient);

    emit RngAuctionCompleted(msg.sender, _rewardRecipient, _requestId, _rewardPortion);
  }

  /* ============ State Functions ============ */

  /**
   * @notice Returns whether the RNG request has been started for the current draw period.
   * @return True if the RNG request has been started, false otherwise.
   */
  function isRngRequested() external view returns (bool) {
    return _isRngRequested();
  }

  /**
   * @notice Returns whether the RNG request has completed or not for the current draw window.
   * @return True if the RNG request has completed, false otherwise.
   */
  function isRngCompleted() external view returns (bool) {
    return _isRngCompleted();
  }

  /**
   * @notice Returns whether the RNG auction is open for the current draw period.
   * @return True if the RNG auction is still open, false otherwise.
   * @dev Use this to determine if you can still start the RNG request for the current draw period.
   */
  function isRngAuctionOpen() external view returns (bool) {
    return !_isRngRequested() && _rngAuctionElapsedTime() <= _auctionDurationSeconds;
  }

  /**
   * @notice Calculates the elapsed time for the current RNG auction.
   * @return The elapsed time since the start of the current RNG auction in seconds.
   */
  function rngAuctionElapsedTime() external view returns (uint64) {
    return _rngAuctionElapsedTime();
  }

  /* ============ Getter Functions ============ */

  /**
   * @notice Returns the current RNG request.
   * @return The current RNG request data
   */
  function getRngRequest() external view returns (RngRequest memory) {
    return _rngRequest;
  }

  /**
   * @notice Returns the ID of the current RNG request.
   * @dev Will return 0 if there is no RNG request in progress.
   * @return ID of the current RNG request
   */
  function getRngRequestId() external view returns (uint32) {
    return _rngRequest.id;
  }

  /**
   * @notice Returns the RNG service used to generate random numbers.
   * @return RNG service instance
   */
  function getRngService() external view returns (RNGInterface) {
    return _rng;
  }

  /**
   * @notice Returns the draw period offset.
   * @return The draw period offset in seconds
   */
  function getDrawPeriodOffset() external view returns (uint64) {
    return _drawPeriodOffset;
  }

  /**
   * @notice Returns the draw period duration.
   * @return The draw period duration in seconds
   */
  function getDrawPeriod() external view returns (uint64) {
    return _drawPeriodSeconds;
  }

  /**
   * @notice Returns the auction duration.
   * @return The auction duration in seconds
   */
  function getAuctionDuration() external view returns (uint64) {
    return _auctionDurationSeconds;
  }

  /* ============ Setters ============ */

  /**
   * @notice Sets the RNG service used to generate random numbers.
   * @dev Only callable by the owner.
   * @dev Will revert if an RNG request is in progress (if the auction is open, then there is no active RNG request).
   * @param _rngService Address of the new RNG service
   */
  function setRngService(RNGInterface _rngService) external onlyOwner requireRngNotRequested {
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
   * @notice Calculates a unique identifier for the current draw window.
   * @return The current draw window ID.
   */
  function _currentDrawWindow() internal view returns (uint32) {
    /**
     * Use integer division to calculate a unique ID based off the current timestamp that will remain the same
     * throughout the entire draw period.
     */
    return uint32((_currentTime() - _drawPeriodOffset) / _drawPeriodSeconds);
  }

  /**
   * @notice Calculates the elapsed time for the current RNG auction.
   * @return The elapsed time since the start of the current RNG auction in seconds.
   */
  function _rngAuctionElapsedTime() internal view returns (uint64) {
    return (_currentTime() - _drawPeriodOffset) % _drawPeriodSeconds;
  }

  /**
   * @notice Returns whether the RNG request has been started for the current draw period.
   * @return True if the RNG request has been started, false otherwise.
   */
  function _isRngRequested() internal view returns (bool) {
    return _rngRequest.drawWindow == _currentDrawWindow();
  }

  /**
   * @notice Returns whether the RNG request has completed or not for the current draw window.
   * @return True if the RNG request has completed, false otherwise.
   */
  function _isRngCompleted() internal view returns (bool) {
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
    if (auctionDurationSeconds_ >= _drawPeriodSeconds)
      revert AuctionDurationGteDrawPeriod(auctionDurationSeconds_, _drawPeriodSeconds);
    _auctionDurationSeconds = auctionDurationSeconds_;
    emit SetAuctionDuration(_auctionDurationSeconds);
  }
}
