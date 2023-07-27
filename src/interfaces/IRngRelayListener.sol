// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { AuctionResults } from "./IAuction.sol";

interface IRngRelayListener {
    function rngComplete(uint256 randomNumber, uint56 rngCompletedAt, address rewardRecipient, AuctionResults auctionResult) external;
}
