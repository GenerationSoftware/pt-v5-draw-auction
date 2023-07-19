// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Phase } from "local-draw-auction/abstract/PhaseManager.sol";

/**
 * @title PoolTogether V5 IDrawManager
 * @author Generation Software Team
 * @notice The IDrawManager provides a common interface for the closing of draws.
 */
interface IDrawManager {
  /**
   * @notice Closes a draw and awards the completers of each auction phase.
   * @param _randomNumber Random number to close the draw with
   * @param _auctionPhases Array of auction phases
   */
  function closeDraw(uint256 _randomNumber, Phase[] memory _auctionPhases) external;
}
