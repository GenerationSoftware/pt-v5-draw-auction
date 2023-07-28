// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import { UD2x18 } from "prb-math/UD2x18.sol";
import { StartRngAuction, RngRequest } from "../../src/StartRngAuction.sol";
import { IRngAuctionRelayListener } from "../../src/interfaces/IRngAuctionRelayListener.sol";
import { AuctionResults } from "../../src/interfaces/IAuction.sol";

import { RngNotCompleted } from "../../src/abstract/RngAuctionRelayer.sol";

contract RngRelayerBaseTest is Test {

    StartRngAuction startRngAuction;
    IRngAuctionRelayListener rngAuctionRelayListener;

    function setUp() public virtual {
        startRngAuction = StartRngAuction(makeAddr("startRngAuction"));
        rngAuctionRelayListener = IRngAuctionRelayListener(makeAddr("rngAuctionRelayListener"));
    }

    /* Mocks */

    function mockIsRngComplete(bool isComplete) public {
        vm.mockCall(address(startRngAuction), abi.encodeWithSelector(startRngAuction.isRngComplete.selector), abi.encode(isComplete));
    }

    function mockRngResults(uint256 _randomNumber, uint64 _rngCompletedAt) public {
        RngRequest memory rngRequest;
        vm.mockCall(address(startRngAuction), abi.encodeWithSelector(startRngAuction.getRngResults.selector), abi.encode(rngRequest, _randomNumber, _rngCompletedAt));
    }

    function mockAuctionResults(address _recipient, UD2x18 _rewardFraction) public {
        AuctionResults memory results;
        results.recipient = _recipient;
        results.rewardFraction = _rewardFraction;
        vm.mockCall(address(startRngAuction), abi.encodeWithSelector(startRngAuction.getAuctionResults.selector), abi.encode(results));
    }

    function mockCurrentSequenceId(uint32 _sequenceId) public {
        vm.mockCall(address(startRngAuction), abi.encodeWithSelector(startRngAuction.currentSequenceId.selector), abi.encode(_sequenceId));
    }

}
