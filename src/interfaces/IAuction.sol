// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Phase } from "local-draw-auction/abstract/PhaseManager.sol";

import { UD2x18 } from "prb-math/UD2x18.sol";

interface IAuction {
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
   * @notice Calculates the reward portion for the current auction if it were to be completed at this time.
   * @dev The implementation of this function may revert if the auction has expired or been completed.
   * @return The current reward portion as a UD2x18 value
   */
  function currentRewardPortion() external view returns (UD2x18);

  /**
   * @notice Calculates if the current auction is complete.
   * @return True if the auction is complete, false otherwise
   */
  function isAuctionComplete() external view returns (bool);
}
