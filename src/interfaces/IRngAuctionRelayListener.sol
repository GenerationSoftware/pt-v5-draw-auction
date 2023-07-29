// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { AuctionResult } from "./IAuction.sol";

interface IRngAuctionRelayListener {
    function rngComplete(
        uint256 randomNumber,
        uint256 rngCompletedAt,
        address rewardRecipient,
        uint32 sequenceId,
        AuctionResult calldata auctionResult
    ) external returns (bytes32);
}
