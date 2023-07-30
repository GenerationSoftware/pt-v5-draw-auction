// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RngAuction } from "../RngAuction.sol";
import { AuctionResult } from "../interfaces/IAuction.sol";
import { AddressRemapper } from "../abstract/AddressRemapper.sol";
import { IRngAuctionRelayListener } from "../interfaces/IRngAuctionRelayListener.sol";

/// @notice Emitted when the RNG has not yet completed
error RngNotCompleted();

/// @title RngAuctionRelayer
/// @author G9 Software Inc.
/// @notice Base contarct that relays RNG auction results to a listener
abstract contract RngAuctionRelayer is AddressRemapper {

    /// @notice The RNG Auction to get the random number from
    RngAuction public immutable rngAuction;

    /// @notice Constructs a new contract
    /// @param _rngAuction The RNG auction to retrieve the random number from
    constructor(
        RngAuction _rngAuction
    ) {
        rngAuction = _rngAuction;
    }

    /// @notice Encodes the calldata for the RNG auction relay listener
    /// @param rewardRecipient The address of the relay reward recipient
    /// @return The calldata to call the listener with
    function encodeCalldata(address rewardRecipient) internal returns (bytes memory) {
        if (!rngAuction.isRngComplete()) revert RngNotCompleted();
        (uint256 randomNumber, uint64 rngCompletedAt) = rngAuction.getRngResults();
        AuctionResult memory results = rngAuction.getLastAuctionResult();
        uint32 sequenceId = rngAuction.openSequenceId();
        results.recipient = remappingOf(results.recipient);
        return abi.encodeWithSelector(IRngAuctionRelayListener.rngComplete.selector, randomNumber, rngCompletedAt, rewardRecipient, sequenceId, results);
    }
}
