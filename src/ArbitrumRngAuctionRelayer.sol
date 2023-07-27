// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StartRngAuction } from "local-draw-auction/StartRngAuction.sol";
import { AuctionResults } from "local-draw-auction/interfaces/IAuction.sol";
import { IStartRngAuctionRelayListener } from "local-draw-auction/interfaces/IStartRngAuctionRelayListener.sol";
import { AddressRemapper } from "local-draw-auction/abstract/AddressRemapper.sol";

contract ArbitrumStartRngAuctionRelayer is AddressRemapper {
    /// @notice Thrown if the RNG request is not complete for the current sequence.
    error RngNotCompleted();

    /// @notice The RNG Auction to get the random number from
    StartRngAuction public immutable startRngAuction;

    IStartRngAuctionRelayListener public immutable rngRelayListener;

    function relay(address rewardRecipient) external {
        if (!startRngAuction.isRngComplete()) revert RngNotCompleted();
        (
            StartRngAuction.RngRequest memory _rngRequest,
            uint256 randomNumber,
            uint64 rngCompletedAt
        ) = startRngAuction.getRngResults();
        (AuctionResults memory results, uint32 sequenceId) = startRngAuction.getAuctionResults();
        results.rewardRecipient = remappingOf(results.rewardRecipient);
        rngRelayListener.rngComplete(randomNumber, rngCompletedAt, rewardRecipient, sequenceId, results);
    }
}
