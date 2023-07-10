// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { RewardLib, Phase, PrizePool } from "draw-auction-local/libraries/RewardLib.sol";

contract RewardLibHarness {
  PrizePool internal _prizePool;
  uint32 internal _auctionDuration;
  Phase[] internal _phases;

  constructor(PrizePool prizePool_, uint8 _auctionPhases, uint32 auctionDuration_) {
    _prizePool = prizePool_;

    for (uint8 i = 0; i < _auctionPhases; i++) {
      _phases.push(
        Phase({ id: i, startTime: uint64(0), endTime: uint64(0), recipient: address(0) })
      );
    }

    _auctionDuration = auctionDuration_;
  }

  function reward(uint8 _phaseId) external view returns (uint256) {
    Phase memory _phase = this.getPhase(_phaseId);
    return RewardLib.reward(_phase, _prizePool, _auctionDuration);
  }

  function setPhase(
    uint8 _phaseId,
    uint64 _startTime,
    uint64 _endTime,
    address _recipient
  ) external returns (Phase memory) {
    Phase memory _phase = Phase({
      id: _phaseId,
      startTime: _startTime,
      endTime: _endTime,
      recipient: _recipient
    });

    _phases[_phaseId] = _phase;

    return _phase;
  }

  function getPhase(uint8 _phaseId) external view returns (Phase memory) {
    return _phases[_phaseId];
  }
}
