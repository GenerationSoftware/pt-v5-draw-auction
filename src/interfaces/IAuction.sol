// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

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

  /**
   * @notice Calculates the elapsed time since the current auction began.
   * @return The elapsed time of the current auction in seconds
   */
  function elapsedTime() external view returns (uint64);

  /**
   * @notice Calculates the reward fraction for the current auction if it were to be completed at this time.
   * @dev The implementation of this function may revert if the auction has expired or been completed.
   * @dev This will return a fractional number between [0,1]
   * @return The current reward fraction as a UD2x18 value
   */
  function currentFractionalReward() external view returns (UD2x18);

  /**
   * @notice Calculates the reward amount if the current auction were to be completed at this time with
   * the given available reserve.
   * @dev The implementation of this function may revert if the auction has expired or been completed.
   * @dev This function will return the actual token amount expected if the given reserve remains the same
   * at the time when the draw is closed.
   * @dev This function takes into account any previous auctions that will be rewarded from the same
   * reserve and returns the reward amount after those deductions are made (i.e. do not subtract any
   * amount from the reserve before passing it to this function).
   * @param reserve The reserve of the prize pool that will be rewarding the auctions
   * @return The expected reward token amount
   */
  function currentRewardAmount(uint256 reserve) external view returns (uint256);

  /**
   * @notice Calculates if the current auction is complete.
   * @return True if the auction is complete, false otherwise
   */
  function isAuctionComplete() external view returns (bool);

  /**
   * @notice Calculates if the current auction is open and can be completed.
   * @return True if the auction is open, false otherwise
   */
  function isAuctionOpen() external view returns (bool);

  /**
   * @notice Returns the results of the last completed auction.
   * @return auctionResults The completed auction results
   * @return sequenceId The sequence ID of the completed auction
   */
  function getAuctionResults()
    external
    view
    returns (AuctionResults memory auctionResults, uint32 sequenceId);
}
