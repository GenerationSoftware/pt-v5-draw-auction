// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { Auction, AuctionLib } from "../../src/auctions/Auction.sol";

contract AuctionHarness is Auction {
  constructor(
    uint8 _auctionPhases,
    uint32 auctionDuration_
  ) Auction(_auctionPhases, auctionDuration_) {}

  function setPhase(
    uint8 _phaseId,
    uint64 _startTime,
    uint64 _endTime,
    address _recipient
  ) external returns (AuctionLib.Phase memory) {
    return _setPhase(_phaseId, _startTime, _endTime, _recipient);
  }
}
