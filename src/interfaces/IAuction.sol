// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { UD2x18 } from "prb-math/UD2x18.sol";

/* ============ Structs ============ */

/**
 * @notice Stores the results of an auction.
 * @param recipient The recipient of the auction awards
 * @param rewardFraction The fraction of the available rewards to be sent to the recipient
 */
struct AuctionResults {
  address recipient;
  UD2x18 rewardFraction;
}

/* ============ Interface ============ */

interface IAuction {
  /* ============ Events ============ */

  /**
   * @notice Emitted when the auction is completed.
   * @param recipient The recipient of the auction awards
   * @param sequenceId The sequence ID for the auction
   * @param elapsedTime The amount of time that the auction ran for in seconds
   * @param rewardFraction The fraction of the available rewards to be sent to the recipient
   */
  event AuctionCompleted(
    address indexed recipient,
    uint32 indexed sequenceId,
    uint64 elapsedTime,
    UD2x18 rewardFraction
  );

  /* ============ Functions ============ */

  /**
   * @notice Returns the auction duration in seconds.
   * @return The auction duration in seconds
   */
  function auctionDuration() external view returns (uint64);

  // function computeRewardFraction(uint256 elapsed) external view returns (uint256);

  // /**
  //  * @notice Calculates if the current auction is complete.
  //  * @return True if the auction is complete, false otherwise
  //  */
  // function isAuctionComplete(uint32 _sequenceId) external view returns (bool);

  /**
   * @notice Returns the results of the last completed auction.
   * @return auctionResults The completed auction results
   */
  function getAuctionResults()
    external
    view
    returns (AuctionResults memory);
}
