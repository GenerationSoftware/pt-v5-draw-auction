// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StartRngAuction } from "../StartRngAuction.sol";
import { AuctionResults } from "../interfaces/IAuction.sol";
import { IRngAuctionRelayListener } from "../interfaces/IRngAuctionRelayListener.sol";
import { AddressRemapper } from "../abstract/AddressRemapper.sol";

error RngNotCompleted();

error CallerNotStartRngAuction();

abstract contract RngAuctionRelayer is AddressRemapper {
    /// @notice Thrown if the RNG request is not complete for the current sequence.
    

    /// @notice The RNG Auction to get the random number from
    StartRngAuction public immutable startRngAuction;
    IRngAuctionRelayListener public immutable rngAuctionRelayListener;

    constructor(
        StartRngAuction _startRngAuction,
        IRngAuctionRelayListener _rngAuctionRelayListener
    ) {
        startRngAuction = _startRngAuction;
        rngAuctionRelayListener = _rngAuctionRelayListener;
    }

    function encodeCalldata(address rewardRecipient) internal returns (bytes memory) {
        if (!startRngAuction.isRngComplete()) revert RngNotCompleted();
        (, uint256 randomNumber, uint64 rngCompletedAt) = startRngAuction.getRngResults();
        AuctionResults memory results = startRngAuction.getAuctionResults();
        uint32 sequenceId = startRngAuction.currentSequenceId();
        results.recipient = remappingOf(results.recipient);
        return abi.encodeWithSelector(IRngAuctionRelayListener.rngComplete.selector, randomNumber, rngCompletedAt, rewardRecipient, sequenceId, results);
    }
}
