// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/console2.sol";

import {
    RngAuctionRelayer,
    StartRngAuction,
    IRngAuctionRelayListener
} from "./abstract/RngAuctionRelayer.sol";

error DirectRelayFailed(bytes returnData);

contract RngAuctionRelayerDirect is RngAuctionRelayer {

    event DirectRelaySuccess(address indexed rewardRecipient, bytes returnData);

    constructor(
        StartRngAuction _startRngAuction,
        IRngAuctionRelayListener _rngAuctionRelayListener
    ) RngAuctionRelayer(_startRngAuction, _rngAuctionRelayListener) {
    }

    function relay(address rewardRecipient) external returns (bytes memory) {
        bytes memory data = encodeCalldata(rewardRecipient);
        (bool success, bytes memory returnData) = address(rngAuctionRelayListener).call(data);
        if (!success) {
            revert DirectRelayFailed(returnData);
        }
        emit DirectRelaySuccess(rewardRecipient, returnData);

        return returnData;
    }
}
