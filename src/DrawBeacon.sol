// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "owner-manager/Ownable.sol";
import { RNGInterface } from "rng/RNGInterface.sol";
import { PrizePool } from "v5-prize-pool/PrizePool.sol";

contract DrawBeacon is Ownable {
  using SafeERC20 for IERC20;

  /* ============ Variables ============ */

  /// @notice PrizePool contract address.
  PrizePool internal prizePool;

  /// @notice RNG contract address.
  RNGInterface internal rng;

  /// @notice Current RNG Request.
  RngRequest internal rngRequest;

  /**
   * @notice RNG Request Timeout. In fact, this is really a "complete draw" timeout.
   * @dev If the rng completes the award can still be cancelled.
   */
  uint32 internal rngTimeout;

  /// @notice Seconds between beacon period request.
  uint32 internal beaconPeriodSeconds;

  /// @notice Epoch timestamp when beacon period can start.
  uint64 internal beaconPeriodStartedAt;

  /**
   * @notice Next Draw ID to use when creating a new draw.
   * @dev Starts at 1. This way we know that no Draw has been recorded at 0.
   */
  uint32 internal nextDrawId;

  /* ============ Structs ============ */

  /**
   * @notice RNG Request.
   * @param id          RNG request ID
   * @param lockBlock   Block number that the RNG request is locked
   * @param requestedAt Time when RNG is requested
   */
  struct RngRequest {
    uint32 id;
    uint32 lockBlock;
    uint64 requestedAt;
  }

  /* ============ Events ============ */

  /**
   * @notice Emitted when a draw has opened.
   * @param startedAt Start timestamp
   */
  event BeaconPeriodStarted(uint64 indexed startedAt);

  /**
   * @notice Emitted when a draw has started.
   * @param rngRequestId Request id
   * @param rngLockBlock Block when draw becomes invalid
   */
  event DrawStarted(uint32 indexed rngRequestId, uint32 rngLockBlock);

  /**
   * @notice Emitted when a draw has been cancelled.
   * @param rngRequestId Request id
   * @param rngLockBlock Block when draw becomes invalid
   */
  event DrawCancelled(uint32 indexed rngRequestId, uint32 rngLockBlock);

  /**
   * @notice Emitted when a draw has been completed.
   * @param randomNumber Random number generated for the draw
   */
  event DrawCompleted(uint256 randomNumber);

  /**
   * @notice Emitted when the drawPeriodSeconds is set.
   * @param drawPeriodSeconds Time between draws in seconds
   */
  event BeaconPeriodSecondsSet(uint32 drawPeriodSeconds);

  /**
   * @notice Emitted when the PrizePool address is set.
   * @param prizePool PrizePool address
   */
  event PrizePoolSet(PrizePool indexed prizePool);

  /**
   * @notice Emitted when the RNG service address is set.
   * @param rngService RNG service address
   */
  event RngServiceSet(RNGInterface indexed rngService);

  /**
   * @notice Emitted when the draw timeout param is set.
   * @param rngTimeout Draw timeout param in seconds
   */
  event RngTimeoutSet(uint32 rngTimeout);

  /* ============ Modifiers ============ */

  modifier requireDrawNotStarted() {
    require(
      rngRequest.lockBlock == 0 || block.number < rngRequest.lockBlock,
      "DrawBeacon/rng-in-flight"
    );
    _;
  }

  modifier requireCanStartDraw() {
    require(_isBeaconPeriodOver(), "DrawBeacon/beaconPeriod-not-over");
    require(!isRngRequested(), "DrawBeacon/rng-already-requested");
    _;
  }

  modifier requireCanCompleteRngRequest() {
    require(isRngRequested(), "DrawBeacon/rng-not-requested");
    require(isRngCompleted(), "DrawBeacon/rng-not-complete");
    _;
  }

  /* ============ Constructor ============ */

  /**
   * @notice Deploy the DrawBeacon smart contract.
   * @param _owner Address of the DrawBeacon owner
   * @param _prizePool Address of the prize pool
   * @param _rng Address of the RNG service
   * @param _nextDrawId Draw ID at which the DrawBeacon will start. Can't be inferior to 1.
   * @param _beaconPeriodStart The starting timestamp of the beacon period
   * @param _beaconPeriodSeconds The duration of the beacon period in seconds
   * @param _rngTimeout Time in seconds before a draw can be cancelled
   */
  constructor(
    address _owner,
    PrizePool _prizePool,
    RNGInterface _rng,
    uint32 _nextDrawId,
    uint64 _beaconPeriodStart,
    uint32 _beaconPeriodSeconds,
    uint32 _rngTimeout
  ) Ownable(_owner) {
    require(_beaconPeriodStart > 0, "DrawBeacon/beacon-period-gt-zero");
    require(_nextDrawId >= 1, "DrawBeacon/next-draw-id-gte-one");

    beaconPeriodStartedAt = _beaconPeriodStart;
    nextDrawId = _nextDrawId;

    _setBeaconPeriodSeconds(_beaconPeriodSeconds);
    _setPrizePool(_prizePool);
    _setRngService(_rng);
    _setRngTimeout(_rngTimeout);
  }

  /* ============ Public Functions ============ */

  /**
   * @notice Returns whether the random number request has completed or not.
   * @return True if a random number request has completed, false otherwise.
   */
  function isRngCompleted() public view returns (bool) {
    return rng.isRequestComplete(rngRequest.id);
  }

  /**
   * @notice Returns whether a random number has been requested or not.
   * @return True if a random number has been requested, false otherwise.
   */
  function isRngRequested() public view returns (bool) {
    return rngRequest.id != 0;
  }

  /**
   * @notice Returns whether the random number request has timed out or not.
   * @return True if a random number request has timed out, false otherwise.
   */
  function isRngTimedOut() public view returns (bool) {
    if (rngRequest.requestedAt == 0) {
      return false;
    } else {
      return rngTimeout + rngRequest.requestedAt < _currentTime();
    }
  }

  /* ============ External Functions ============ */

  /**
   * @notice Returns whether a Draw can be started or not.
   * @return True if a Draw can be started, false otherwise.
   */
  function canStartDraw() external view returns (bool) {
    return _isBeaconPeriodOver() && !isRngRequested();
  }

  /**
   * @notice Returns whether a Draw can be completed or not.
   * @return True if a Draw can be completed, false otherwise.
   */
  function canCompleteDraw() external view returns (bool) {
    return isRngRequested() && isRngCompleted();
  }

  /**
   * @notice Calculates the next beacon start time, assuming all beacon periods have occurred between the last and now.
   * @return The next beacon period start time.
   */
  function calculateNextBeaconPeriodStartTimeFromCurrentTime() external view returns (uint64) {
    return
      _calculateNextBeaconPeriodStartTime(
        beaconPeriodStartedAt,
        beaconPeriodSeconds,
        _currentTime()
      );
  }

  /**
   * @notice Calculates when the next beacon period will start.
   * @param _time Timestamp to use as the current time
   * @return Timestamp at which the next beacon period will start.
   */
  function calculateNextBeaconPeriodStartTime(uint64 _time) external view returns (uint64) {
    return _calculateNextBeaconPeriodStartTime(beaconPeriodStartedAt, beaconPeriodSeconds, _time);
  }

  /// @notice Can be called by anyone to cancel the draw request if the RNG has timed out.
  function cancelDraw() external {
    require(isRngTimedOut(), "DrawBeacon/rng-not-timedout");
    uint32 requestId = rngRequest.id;
    uint32 lockBlock = rngRequest.lockBlock;
    delete rngRequest;
    emit DrawCancelled(requestId, lockBlock);
  }

  /// @notice Completes the Draw (RNG) request and award the PrizePool.
  function completeDraw() external requireCanCompleteRngRequest {
    uint256 _randomNumber = rng.randomNumber(rngRequest.id);
    uint64 _beaconPeriodStartedAt = beaconPeriodStartedAt;
    uint32 _beaconPeriodSeconds = beaconPeriodSeconds;
    uint64 _time = _currentTime();

    uint32 _lastCompletedDrawId = prizePool.completeAndStartNextDraw(_randomNumber);

    // To avoid clock drift, we should calculate the start time based on the previous period start time.
    uint64 _nextBeaconPeriodStartedAt = _calculateNextBeaconPeriodStartTime(
      _beaconPeriodStartedAt,
      _beaconPeriodSeconds,
      _time
    );

    beaconPeriodStartedAt = _nextBeaconPeriodStartedAt;
    nextDrawId = _lastCompletedDrawId + 1;

    // Reset the rngRequest state so Beacon period can start again.
    delete rngRequest;

    emit DrawCompleted(_randomNumber);
    emit BeaconPeriodStarted(_nextBeaconPeriodStartedAt);
  }

  /**
   * @notice Returns the number of seconds remaining until the beacon period can be complete.
   * @return The number of seconds remaining until the beacon period can be complete.
   */
  function beaconPeriodRemainingSeconds() external view returns (uint64) {
    return _beaconPeriodRemainingSeconds();
  }

  /**
   * @notice Returns the timestamp at which the beacon period ends
   * @return The timestamp at which the beacon period ends.
   */
  function beaconPeriodEndAt() external view returns (uint64) {
    return _beaconPeriodEndAt();
  }

  function getBeaconPeriodSeconds() external view returns (uint32) {
    return beaconPeriodSeconds;
  }

  function getBeaconPeriodStartedAt() external view returns (uint64) {
    return beaconPeriodStartedAt;
  }

  function getNextDrawId() external view returns (uint32) {
    return nextDrawId;
  }

  /**
   * @notice Returns the block number that the current RNG request has been locked to.
   * @return The block number that the RNG request is locked to.
   */
  function getLastRngLockBlock() external view returns (uint32) {
    return rngRequest.lockBlock;
  }

  function getLastRngRequestId() external view returns (uint32) {
    return rngRequest.id;
  }

  function getRngService() external view returns (RNGInterface) {
    return rng;
  }

  function getRngTimeout() external view returns (uint32) {
    return rngTimeout;
  }

  /**
   * @notice Returns whether the beacon period is over or not.
   * @return True if the beacon period is over, false otherwise.
   */
  function isBeaconPeriodOver() external view returns (bool) {
    return _isBeaconPeriodOver();
  }

  /**
   * @notice Starts the Draw process by starting random number request. The previous beacon period must have ended.
   * @dev If the RNG Service request a `feeToken` for payment,
   *      the RNG-Request-Fee is expected to be held within this contract before calling this function.
   */
  function startDraw() external requireCanStartDraw {
    (address feeToken, uint256 requestFee) = rng.getRequestFee();

    if (feeToken != address(0) && requestFee > 0) {
      IERC20(feeToken).safeIncreaseAllowance(address(rng), requestFee);
    }

    (uint32 requestId, uint32 lockBlock) = rng.requestRandomNumber();
    rngRequest.id = requestId;
    rngRequest.lockBlock = lockBlock;
    rngRequest.requestedAt = _currentTime();

    emit DrawStarted(requestId, lockBlock);
  }

  /**
   * @notice Allows the owner to set the beacon period in seconds.
   * @param _beaconPeriodSeconds The new beacon period in seconds. Must be greater than zero.
   */
  function setBeaconPeriodSeconds(
    uint32 _beaconPeriodSeconds
  ) external onlyOwner requireDrawNotStarted {
    _setBeaconPeriodSeconds(_beaconPeriodSeconds);
  }

  /**
   * @notice Sets the PrizePool that will compute the Draw.
   * @param _prizePool Address of the new PrizePool
   */
  function setPrizePool(PrizePool _prizePool) external onlyOwner requireDrawNotStarted {
    _setPrizePool(_prizePool);
  }

  /**
   * @notice Sets the RNG service that the Prize Strategy is connected to.
   * @param _rngService The address of the new RNG service interface
   */
  function setRngService(RNGInterface _rngService) external onlyOwner requireDrawNotStarted {
    _setRngService(_rngService);
  }

  /**
   * @notice Allows the owner to set the RNG request timeout in seconds. This is the time that must elapsed before the RNG request can be cancelled and the pool unlocked.
   * @param _rngTimeout The RNG request timeout in seconds
   */
  function setRngTimeout(uint32 _rngTimeout) external onlyOwner requireDrawNotStarted {
    _setRngTimeout(_rngTimeout);
  }

  /* ============ Internal Functions ============ */

  /**
   * @notice Calculates when the next beacon period will start
   * @param _beaconPeriodStartedAt The timestamp at which the beacon period started
   * @param _beaconPeriodSeconds The duration of the beacon period in seconds
   * @param _time The timestamp to use as the current time
   * @return The timestamp at which the next beacon period will start.
   */
  function _calculateNextBeaconPeriodStartTime(
    uint64 _beaconPeriodStartedAt,
    uint32 _beaconPeriodSeconds,
    uint64 _time
  ) internal pure returns (uint64) {
    uint64 elapsedPeriods = (_time - _beaconPeriodStartedAt) / _beaconPeriodSeconds;
    return _beaconPeriodStartedAt + (elapsedPeriods * _beaconPeriodSeconds);
  }

  /**
   * @notice Returns the current timestamp.
   * @return The current timestamp.
   */
  function _currentTime() internal view virtual returns (uint64) {
    return uint64(block.timestamp);
  }

  /**
   * @notice Returns the timestamp at which the beacon period ends.
   * @return The timestamp at which the beacon period ends.
   */
  function _beaconPeriodEndAt() internal view returns (uint64) {
    return beaconPeriodStartedAt + beaconPeriodSeconds;
  }

  /**
   * @notice Returns the number of seconds remaining until the prize can be awarded.
   * @return The number of seconds remaining until the prize can be awarded.
   */
  function _beaconPeriodRemainingSeconds() internal view returns (uint64) {
    uint64 endAt = _beaconPeriodEndAt();
    uint64 time = _currentTime();

    if (endAt <= time) {
      return 0;
    }

    return endAt - time;
  }

  /**
   * @notice Returns whether the beacon period is over or not.
   * @return True if the beacon period is over, false otherwise.
   */
  function _isBeaconPeriodOver() internal view returns (bool) {
    return _beaconPeriodEndAt() <= _currentTime();
  }

  /**
   * @notice Sets the beacon period in seconds.
   * @param _beaconPeriodSeconds New beacon period in seconds. Must be greater than zero.
   */
  function _setBeaconPeriodSeconds(uint32 _beaconPeriodSeconds) internal {
    require(_beaconPeriodSeconds > 0, "DrawBeacon/beacon-period-gt-zero");
    beaconPeriodSeconds = _beaconPeriodSeconds;

    emit BeaconPeriodSecondsSet(_beaconPeriodSeconds);
  }

  /**
   * @notice Sets the PrizePool that will compute the Draw.
   * @param _prizePool Address of the new PrizePool
   */
  function _setPrizePool(PrizePool _prizePool) internal {
    require(address(_prizePool) != address(0), "DrawBeacon/PP-not-zero-address");
    prizePool = _prizePool;
    emit PrizePoolSet(_prizePool);
  }

  /**
   * @notice Sets the RNG service that the Prize Strategy is connected to
   * @param _rng Address of the new RNG service
   */
  function _setRngService(RNGInterface _rng) internal {
    require(address(_rng) != address(0), "DrawBeacon/rng-not-zero-address");
    rng = _rng;
    emit RngServiceSet(_rng);
  }

  /**
   * @notice Sets the RNG request timeout in seconds. This is the time that must elapse before the RNG request can be cancelled and the pool unlocked.
   * @param _rngTimeout RNG request timeout in seconds
   */
  function _setRngTimeout(uint32 _rngTimeout) internal {
    require(_rngTimeout > 60, "DrawBeacon/rng-timeout-gt-60s");
    rngTimeout = _rngTimeout;
    emit RngTimeoutSet(_rngTimeout);
  }
}
