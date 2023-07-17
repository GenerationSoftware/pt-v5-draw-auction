// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { UD2x18 } from "prb-math/UD2x18.sol";

/**
 * @notice Struct representing the phase of an auction.
 * @param rewardPortion Portion of the max reward for the phase
 * @param recipient Recipient of the phase reward
 */
struct Phase {
  UD2x18 rewardPortion;
  address recipient;
}

abstract contract PhaseManager {
  /* ============ Variables ============ */

  /// @notice Array storing the phases with the index equal to the phase ID
  Phase[] internal _phases;

  /* ============ Custom Errors ============ */

  /// @notice Thrown when the number of auction phases passed to the constructor is zero.
  error AuctionPhasesNotZero();

  /* ============ Events ============ */

  /**
   @notice Emitted when a phase is set.
   @param phaseId Id of the phase
   @param rewardPortion Portion of the max reward for the phase
   @param recipient Recipient of the phase reward
   */
  event AuctionPhaseSet(uint8 indexed phaseId, UD2x18 rewardPortion, address indexed recipient);

  /* ============ Constructor ============ */

  /**
   * @notice Contract constructor.
   * @param _auctionPhases Number of auction phases
   */
  constructor(uint8 _auctionPhases) {
    if (_auctionPhases == 0) revert AuctionPhasesNotZero();

    for (uint8 i = 0; i < _auctionPhases; i++) {
      _phases.push(Phase({ rewardPortion: UD2x18.wrap(0), recipient: address(0) }));
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
   * @notice Get phase by ID.
   * @param _phaseId ID of the phase
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
   * @notice Get phase by ID.
   * @param _phaseId ID of the phase
   * @return Phase
   */
  function _getPhase(uint256 _phaseId) internal view returns (Phase memory) {
    return _phases[_phaseId];
  }

  /* ============ Setters ============ */

  /**
   * @notice Set phase.
   * @param _phaseId ID of the phase
   * @param _rewardPortion Portion of the max reward for the phase
   * @param _recipient Recipient of the phase reward
   * @return Phase
   */
  function _setPhase(
    uint8 _phaseId,
    UD2x18 _rewardPortion,
    address _recipient
  ) internal returns (Phase memory) {
    _phases[_phaseId].rewardPortion = _rewardPortion;
    _phases[_phaseId].recipient = _recipient;

    emit AuctionPhaseSet(_phaseId, _rewardPortion, _recipient);

    return _phases[_phaseId];
  }
}
