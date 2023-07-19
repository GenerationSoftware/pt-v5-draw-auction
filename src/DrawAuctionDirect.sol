// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { RNGInterface } from "rng/RNGInterface.sol";

import { RngAuction } from "local-draw-auction/RngAuction.sol";
import { DrawManager } from "local-draw-auction/DrawManager.sol";
import { Phase } from "local-draw-auction/abstract/PhaseManager.sol";
import { DrawAuction } from "local-draw-auction/abstract/DrawAuction.sol";

/**
 * @title   PoolTogether V5 DirectDrawAuction
 * @author  Generation Software Team
 * @notice  The DirectDrawAuction sends the results of the draw auction to the draw manager.
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
   * @param rngAuction_ The RngAuction to get the random number from
   * @param auctionDurationSeconds_ Auction duration in seconds
   */
  constructor(
    DrawManager drawManager_,
    RngAuction rngAuction_,
    uint64 auctionDurationSeconds_
  ) DrawAuction(rngAuction_, auctionDurationSeconds_) {
    if (address(drawManager_) == address(0)) revert DrawManagerZeroAddress();
    drawManager = drawManager_;
  }

  /* ============ Hook Overrides ============ */

  /**
   * @inheritdoc DrawAuction
   * @dev Calls the DrawManager with the random number and auction results.
   */
  function _afterDrawAuction(uint256 _randomNumber) internal override {
    Phase[] memory _phases = new Phase[](2);
    _phases[0] = rngAuction.getPhase();
    _phases[1] = _phase;
    drawManager.closeDraw(_randomNumber, _phases);
  }
}