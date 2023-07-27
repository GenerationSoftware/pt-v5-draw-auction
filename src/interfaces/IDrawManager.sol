// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { AuctionResults } from "local-draw-auction/interfaces/IAuction.sol";

/**
 * @title PoolTogether V5 IDrawManager
 * @author Generation Software Team
 * @notice The IDrawManager provides a common interface for the closing of draws.
 */
interface IDrawManager {
  /**
   * @notice Closes a draw and awards the completers of each auction.
   * @param _randomNumber Random number to close the draw with
   * @param _auctionResults Array of auction results
   */
  function closeDraw(uint256 _randomNumber, AuctionResults[] memory _auctionResults) external;
}
