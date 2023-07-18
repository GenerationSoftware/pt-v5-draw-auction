// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { RNGInterface } from "rng/RNGInterface.sol";
import { UD2x18 } from "prb-math/UD2x18.sol";

import { DrawAuction } from "local-draw-auction/abstract/DrawAuction.sol";
import { PhaseManager, Phase } from "local-draw-auction/abstract/PhaseManager.sol";
import { RewardLib } from "local-draw-auction/libraries/RewardLib.sol";
import { RngAuction } from "local-draw-auction/RngAuction.sol";

contract DrawAuctionHarness is DrawAuction {
  uint256 public afterCompleteDrawCounter;
  uint256 public lastRandomNumber;

  constructor(
    RngAuction rngAuction_,
    uint64 auctionDurationSeconds_,
    uint8 auctionPhases_
  ) DrawAuction(rngAuction_, auctionDurationSeconds_, auctionPhases_) {}

  /**
   * @dev counts the number of times the hook is called
   */
  function _afterCompleteDraw(uint256 _randomNumber) internal override {
    lastRandomNumber = _randomNumber;
    afterCompleteDrawCounter = afterCompleteDrawCounter + 1;
  }
}
