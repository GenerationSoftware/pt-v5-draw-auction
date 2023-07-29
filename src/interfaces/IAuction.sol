// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { UD2x18 } from "prb-math/UD2x18.sol";

/* ============ Structs ============ */

/**
 * @notice Stores the results of an auction.
 * @param recipient The recipient of the auction awards
 * @param rewardFraction The fraction of the available rewards to be sent to the recipient
 */
struct AuctionResult {
  address recipient;
  UD2x18 rewardFraction;
}

/* ============ Interface ============ */

interface IAuction {
  /* ============ Functions ============ */

  /**
   * @notice Returns the auction duration in seconds.
   * @return The auction duration in seconds
   */
  function auctionDuration() external view returns (uint64);

  function lastSequenceId() external view returns (uint32);

  function computeRewardFraction(uint64 _auctionElapsedTime) external view returns (UD2x18);

  /**
   * @notice Returns the results of the last completed auction.
   * @return auctionResults The completed auction results
   */
  function getLastAuctionResult() external view returns (AuctionResult memory);
}
