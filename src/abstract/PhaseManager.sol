// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

/**
 * @notice Struct representing the phase of an auction.
 * @param id Id of the phase
 * @param startTime Start time of the phase
 * @param endTime End time of the phase
 * @param recipient Recipient of the phase reward
 */
struct Phase {
  uint8 id;
  uint64 startTime;
  uint64 endTime;
  address recipient;
}

contract PhaseManager {
  /* ============ Variables ============ */

  /// @notice Array storing phases per id in ascending order.
  Phase[] internal _phases;

  /* ============ Custom Errors ============ */

  /// @notice Thrown when the number of auction phases passed to the constructor is zero.
  error AuctionPhasesNotZero();

  /* ============ Events ============ */

  /**
   @notice Emitted when a phase is set.
   @param phaseId Id of the phase
   @param startTime Start time of the phase
   @param endTime End time of the phase
   @param recipient Recipient of the phase reward
   */
  event AuctionPhaseSet(
    uint8 indexed phaseId,
    uint64 startTime,
    uint64 endTime,
    address indexed recipient
  );

  /**
   * @notice Emitted when an auction phase has completed.
   * @param phaseId Id of the phase
   * @param caller Address of the caller
   */
  event AuctionPhaseCompleted(uint256 indexed phaseId, address indexed caller);

  /* ============ Constructor ============ */

  /**
   * @notice Contract constructor.
   * @param _auctionPhases Number of auction phases
   */
  constructor(uint8 _auctionPhases) {
    if (_auctionPhases == 0) revert AuctionPhasesNotZero();

    for (uint8 i = 0; i < _auctionPhases; i++) {
      _phases.push(
        Phase({ id: i, startTime: uint64(0), endTime: uint64(0), recipient: address(0) })
      );
    }
  }

  /* ============ External Functions ============ */

  /* ============ Getters ============ */

  /**
   * @notice Get phases.
   * @return Phases
   */
  function getPhases() external view returns (Phase[] memory) {
    return _getPhases();
  }

  /**
   * @notice Get phase by id.
   * @param _phaseId Id of the phase
   * @return Phase
   */
  function getPhase(uint256 _phaseId) external view returns (Phase memory) {
    return _getPhase(_phaseId);
  }

  /* ============ Internal Functions ============ */

  /* ============ Getters ============ */

  /**
   * @notice Get phases.
   * @return Phases
   */
  function _getPhases() internal view returns (Phase[] memory) {
    return _phases;
  }

  /**
   * @notice Get phase by id.
   * @param _phaseId Id of the phase
   * @return Phase
   */
  function _getPhase(uint256 _phaseId) internal view returns (Phase memory) {
    return _phases[_phaseId];
  }

  /* ============ Setters ============ */

  /**
   * @notice Set phase.
   * @param _phaseId Id of the phase
   * @param _startTime Start time of the phase
   * @param _endTime End time of the phase
   * @param _recipient Recipient of the phase reward
   * @return Phase
   */
  function _setPhase(
    uint8 _phaseId,
    uint64 _startTime,
    uint64 _endTime,
    address _recipient
  ) internal returns (Phase memory) {
    Phase memory _phase = Phase({
      id: _phaseId,
      startTime: _startTime,
      endTime: _endTime,
      recipient: _recipient
    });

    _phases[_phaseId] = _phase;

    emit AuctionPhaseSet(_phaseId, _startTime, _endTime, _recipient);

    return _phase;
  }
}
