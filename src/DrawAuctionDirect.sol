// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { RNGInterface } from "rng/RNGInterface.sol";

import { RNGAuction } from "local-draw-auction/RNGAuction.sol";
import { DrawManager } from "local-draw-auction/DrawManager.sol";
import { DrawAuction } from "local-draw-auction/abstract/DrawAuction.sol";

/**
 * @title   PoolTogether V5 DirectDrawAuction
 * @author  Generation Software Team
 * @notice  The DirectDrawAuction sends the results of the draw auction directly to the prize
 *          pool on the same chain.
 */
contract DirectDrawAuction is DrawAuction {
  /* ============ Constants ============ */

  /// @notice The DrawManager to send the auction results to
  DrawManager public immutable drawManager;

  /* ============ Custom Errors ============ */

  /// @notice Thrown if the DrawManager address is the zero address.
  error DrawManagerZeroAddress();

  /* ============ Constructor ============ */

  /**
   * @notice Deploy the DirectDrawAuction smart contract.
   * @param drawManager_ The DrawManager to send the auction results to
   * @param rngAuction_ The RNGAuction to get the random number from
   * @param auctionDurationSeconds_ Auction duration in seconds
   * @param auctionName_ Name of the auction
   */
  constructor(
    DrawManager drawManager_,
    RNGAuction rngAuction_,
    uint64 auctionDurationSeconds_,
    string memory auctionName_
  ) DrawAuction(rngAuction_, auctionDurationSeconds_, 2, auctionName_) {
    if (address(drawManager_) == address(0)) revert DrawManagerZeroAddress();
    drawManager = drawManager_;
  }

  /* ============ Hook Overrides ============ */

  /**
   * @inheritdoc DrawAuction
   * @dev Calls the DrawManager with the random number and auction results.
   */
  function _afterCompleteDraw(uint256 _randomNumber) internal override {
    drawManager.closeDraw(_randomNumber, _getPhases());
  }
}
