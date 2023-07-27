// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { AuctionResults } from "./IAuction.sol";

interface IStartRngAuctionRelayListener {
    function rngComplete(
        uint256 randomNumber,
        uint56 rngCompletedAt,
        address rewardRecipient,
        uint32 sequenceId,
        AuctionResults calldata auctionResult
    ) external;
}
