// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    RngAuctionRelayer,
    RngAuction,
    IRngAuctionRelayListener
} from "./abstract/RngAuctionRelayer.sol";

/// @notice Emitted when the relay call fails
/// @param returnData The revert message from the relay call
error DirectRelayFailed(bytes returnData);

/// @title RngAuctionRelayerDirect
/// @author G9 Software Inc.
/// @notice This contract will allow anyone to trigger the relay of RNG results to an IRngAuctionRelayListener.
contract RngAuctionRelayerDirect is RngAuctionRelayer {

    /// @notice Emitted when the relay was successful.
    /// @param rewardRecipient The address of the reward recipient.
    /// @param returnData The return data from the relay listener.
    event DirectRelaySuccess(address indexed rewardRecipient, bytes returnData);

    /// @notice Constructs a new contract
    /// @param _rngAuction The RNG auction to pull results from.
    constructor(RngAuction _rngAuction) RngAuctionRelayer(_rngAuction) {
    }

    /// @notice Relays the RNG results to an IRngAuctionRelayListener.
    /// @dev The RNG request must complete before this call can be made
    /// @param _rngAuctionRelayListener The address of the IRngAuctionRelayListener to relay to.
    /// @param _relayRewardRecipient The address that shall receive the RngAuctionRelay reward.
    /// @return The return value from the relay listener.
    function relay(
        IRngAuctionRelayListener _rngAuctionRelayListener,
        address _relayRewardRecipient
    ) external returns (bytes memory) {
        bytes memory data = _encodeCalldata(_relayRewardRecipient);
        (bool success, bytes memory returnData) = address(_rngAuctionRelayListener).call(data);
        if (!success) {
            revert DirectRelayFailed(returnData);
        }
        emit DirectRelaySuccess(_relayRewardRecipient, returnData);
        return returnData;
    }
}
