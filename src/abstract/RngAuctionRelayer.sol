// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/console2.sol";

import { RngAuction } from "../RngAuction.sol";
import { AuctionResult } from "../interfaces/IAuction.sol";
import { AddressRemapper } from "../abstract/AddressRemapper.sol";
import { IRngAuctionRelayListener } from "../interfaces/IRngAuctionRelayListener.sol";

error RngNotCompleted();

error CallerNotRngAuction();

abstract contract RngAuctionRelayer is AddressRemapper {
    /// @notice Thrown if the RNG request is not complete for the current sequence.
    

    /// @notice The RNG Auction to get the random number from
    RngAuction public immutable startRngAuction;

    constructor(
        RngAuction _startRngAuction
    ) {
        startRngAuction = _startRngAuction;
    }

    function encodeCalldata(address rewardRecipient) internal returns (bytes memory) {
        if (!startRngAuction.isRngComplete()) revert RngNotCompleted();
        (uint256 randomNumber, uint64 rngCompletedAt) = startRngAuction.getRngResults();
        AuctionResult memory results = startRngAuction.getLastAuctionResult();
        uint32 sequenceId = startRngAuction.openSequenceId();
        results.recipient = remappingOf(results.recipient);
        return abi.encodeWithSelector(IRngAuctionRelayListener.rngComplete.selector, randomNumber, rngCompletedAt, rewardRecipient, sequenceId, results);
    }
}
