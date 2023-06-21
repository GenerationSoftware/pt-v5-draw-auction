// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

contract AuctionLib {
  /* ============ Structs ============ */

  /**
   * @notice Struct representing the phase of an auction.
   * @param id Id of the phase
   * @param startTime Start time of the phase
   * @param endTime End time of the phase
   * @param recipient Recipient of the phase reward
   */
  struct Phase {
    uint8 id;
    uint64 startTime;
    uint64 endTime;
    address recipient;
  }
}
