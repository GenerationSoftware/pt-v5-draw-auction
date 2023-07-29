// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/console2.sol";

import {
    RngAuctionRelayer,
    RngAuction,
    IRngAuctionRelayListener
} from "./abstract/RngAuctionRelayer.sol";

error DirectRelayFailed(bytes returnData);

contract RngAuctionRelayerDirect is RngAuctionRelayer {

    event DirectRelaySuccess(address indexed rewardRecipient, bytes returnData);

    constructor(RngAuction _startRngAuction) RngAuctionRelayer(_startRngAuction) {
    }

    function relay(
        IRngAuctionRelayListener _rngAuctionRelayListener,
        address _relayRewardRecipient
    ) external returns (bytes memory) {
        bytes memory data = encodeCalldata(_relayRewardRecipient);
        (bool success, bytes memory returnData) = address(_rngAuctionRelayListener).call(data);
        if (!success) {
            revert DirectRelayFailed(returnData);
        }
        emit DirectRelaySuccess(_relayRewardRecipient, returnData);

        return returnData;
    }
}
