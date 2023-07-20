// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { RNGInterface } from "rng/RNGInterface.sol";
import { UD2x18 } from "prb-math/UD2x18.sol";

import { DrawAuction } from "local-draw-auction/abstract/DrawAuction.sol";
import { RewardLib } from "local-draw-auction/libraries/RewardLib.sol";
import { RngAuction } from "local-draw-auction/RngAuction.sol";

contract DrawAuctionHarness is DrawAuction {
  uint256 public afterDrawAuctionCounter;
  uint256 public lastRandomNumber;

  constructor(
    RngAuction rngAuction_,
    uint64 auctionDurationSeconds_
  ) DrawAuction(rngAuction_, auctionDurationSeconds_) {}

  /**
   * @dev counts the number of times the hook is called
   */
  function _afterDrawAuction(uint256 _randomNumber) internal override {
    lastRandomNumber = _randomNumber;
    afterDrawAuctionCounter = afterDrawAuctionCounter + 1;
  }
}
