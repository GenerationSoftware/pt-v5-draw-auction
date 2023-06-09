// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { PrizePool } from "v5-prize-pool/PrizePool.sol";

contract DrawAuction {
  PrizePool internal prizePool;

  uint32 internal _auctionDuration;

  constructor(PrizePool _prizePool, uint32 auctionDuration_) {
    prizePool = _prizePool;
    _auctionDuration = auctionDuration_;
  }

  /// @notice Allows the Manager to complete the current prize period and starts the next one, updating the number of tiers, the winning random number, and the prize pool reserve
  /// @param winningRandomNumber_ The winning random number for the current draw
  function completeAndStartNextDraw(uint256 winningRandomNumber_) external {
    uint256 _y = _reward();

    prizePool.completeAndStartNextDraw(winningRandomNumber_);

    prizePool.withdrawReserve(msg.sender, uint104(_y));
  }

  function reward() external view returns (uint256) {
    return _reward();
  }

  function _reward() internal view returns (uint256) {
    uint256 _nextDrawEndsAt = prizePool.nextDrawEndsAt();

    if (block.timestamp < _nextDrawEndsAt) {
      return 0;
    }

    uint256 _reserve = prizePool.reserve() + prizePool.reserveForNextDraw();
    uint256 _elapsedTime = block.timestamp - _nextDrawEndsAt;

    return
      _elapsedTime >= _auctionDuration ? _reserve : (_elapsedTime * _reserve) / _auctionDuration;
  }

  function auctionDuration() external view returns (uint256) {
    return _auctionDuration;
  }
}
