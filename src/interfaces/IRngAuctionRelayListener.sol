// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { AuctionResults } from "./IAuction.sol";

interface IRngAuctionRelayListener {
    function rngComplete(
        uint256 randomNumber,
        uint256 rngCompletedAt,
        address rewardRecipient,
        uint32 sequenceId,
        AuctionResults calldata auctionResult
    ) external returns (bytes memory);
}
