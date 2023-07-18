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

  /// @notice The phase managed by this contract
  Phase internal _phase;

  /* ============ Events ============ */

  /**
   @notice Emitted when a phase is set.
   @param rewardPortion Portion of the max reward for the phase
   @param recipient Recipient of the phase reward
   */
  event AuctionPhaseSet(UD2x18 rewardPortion, address indexed recipient);

  /* ============ External Functions ============ */

  /* ============ Getters ============ */

  /**
   * @notice Get phase
   * @return Phase
   */
  function getPhase() external view returns (Phase memory) {
    return _phase;
  }

  /* ============ Internal Functions ============ */

  /* ============ Setters ============ */

  /**
   * @notice Set phase.
   * @param _rewardPortion Portion of the max reward for the phase
   * @param _recipient Recipient of the phase reward
   * @return Phase
   */
  function _setPhase(UD2x18 _rewardPortion, address _recipient) internal returns (Phase memory) {
    _phase.rewardPortion = _rewardPortion;
    _phase.recipient = _recipient;

    emit AuctionPhaseSet(_rewardPortion, _recipient);

    return _phase;
  }
}
