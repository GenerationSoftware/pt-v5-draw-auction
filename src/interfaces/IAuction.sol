// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { UD2x18 } from "prb-math/UD2x18.sol";

/* ============ Structs ============ */

/// @notice Stores the results of an auction.
/// @param recipient The recipient of the auction awards
/// @param rewardFraction The fraction of the available rewards to be sent to the recipient
struct AuctionResult {
  address recipient;
  UD2x18 rewardFraction;
}

/* ============ Interface ============ */

/// @title IAuction
/// @author G9 Software Inc.
/// @notice Defines some common interfaces for auctions
interface IAuction {
  /// @notice Returns the auction duration in seconds.
  /// @return The auction duration in seconds
  function auctionDuration() external view returns (uint64);
}
