// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { AuctionLib } from "src/libraries/AuctionLib.sol";

contract Auction {
  /* ============ Variables ============ */

  /// @notice Duration of the auction in seconds.
  uint256 internal _auctionDuration;

  /// @notice Array storing phases per id in ascending order.
  AuctionLib.Phase[] internal _phases;

  /* ============ Custom Errors ============ */

  /// @notice Thrown when the auction duration passed to the constructor is zero.
  error AuctionDurationNotZero();

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
  event PhaseSet(
    uint8 indexed phaseId,
    uint64 startTime,
    uint64 endTime,
    address indexed recipient
  );

  /* ============ Constructor ============ */

  /**
   * @notice Contract constructor.
   * @param _auctionPhases Number of auction phases
   * @param auctionDuration_ Duration of the auction in seconds
   */
  constructor(uint8 _auctionPhases, uint256 auctionDuration_) {
    if (_auctionPhases == 0) revert AuctionPhasesNotZero();
    if (auctionDuration_ == 0) revert AuctionDurationNotZero();

    for (uint8 i = 0; i < _auctionPhases; i++) {
      _phases.push(
        AuctionLib.Phase({ id: i, startTime: uint64(0), endTime: uint64(0), recipient: address(0) })
      );
    }

    _auctionDuration = auctionDuration_;
  }

  /* ============ External Functions ============ */

  /* ============ Getters ============ */

  /**
   * @notice Duration of the auction.
   * @dev This is the time it takes for the auction to reach the PrizePool full reserve amount.
   * @return Duration of the auction in seconds
   */
  function auctionDuration() external view returns (uint256) {
    return _auctionDuration;
  }

  function getPhase(uint256 _phaseId) external view returns (AuctionLib.Phase memory) {
    return _getPhase(_phaseId);
  }

  /* ============ Internal Functions ============ */

  /* ============ Hooks ============ */

  /**
   * @notice Hook called after the auction has ended.
   * @param _randomNumber The random number that was generated
   */
  function _afterAuctionEnds(uint256 _randomNumber) internal virtual {}

  /* ============ Getters ============ */

  function _getPhase(uint256 _phaseId) internal view returns (AuctionLib.Phase memory) {
    return _phases[_phaseId];
  }

  /* ============ Setters ============ */

  function _setPhase(
    uint8 _phaseId,
    uint64 _startTime,
    uint64 _endTime,
    address _recipient
  ) internal returns (AuctionLib.Phase memory) {
    AuctionLib.Phase memory _phase = AuctionLib.Phase({
      id: _phaseId,
      startTime: _startTime,
      endTime: _endTime,
      recipient: _recipient
    });

    _phases[_phaseId] = _phase;

    emit PhaseSet(_phaseId, _startTime, _endTime, _recipient);

    return _phase;
  }
}
