// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import { UD2x18 } from "prb-math/UD2x18.sol";
import { RngAuction } from "../../src/RngAuction.sol";
import { IRngAuctionRelayListener } from "../../src/interfaces/IRngAuctionRelayListener.sol";
import { AuctionResult } from "../../src/interfaces/IAuction.sol";

import { RngNotCompleted } from "../../src/abstract/RngAuctionRelayer.sol";

contract RngRelayerBaseTest is Test {

    RngAuction rngAuction;
    IRngAuctionRelayListener rngAuctionRelayListener;

    function setUp() public virtual {
        rngAuction = RngAuction(makeAddr("rngAuction"));
        rngAuctionRelayListener = IRngAuctionRelayListener(makeAddr("rngAuctionRelayListener"));
    }

    /* Mocks */

    function mockIsRngComplete(bool isComplete) public {
        vm.mockCall(address(rngAuction), abi.encodeWithSelector(rngAuction.isRngComplete.selector), abi.encode(isComplete));
    }

    function mockRngResults(uint256 _randomNumber, uint64 _rngCompletedAt) public {
        vm.mockCall(address(rngAuction), abi.encodeWithSelector(rngAuction.getRngResults.selector), abi.encode(_randomNumber, _rngCompletedAt));
    }

    function mockAuctionResult(address _recipient, UD2x18 _rewardFraction) public {
        AuctionResult memory results;
        results.recipient = _recipient;
        results.rewardFraction = _rewardFraction;
        vm.mockCall(address(rngAuction), abi.encodeWithSelector(rngAuction.getLastAuctionResult.selector), abi.encode(results));
    }

    function mockCurrentSequenceId(uint32 _sequenceId) public {
        vm.mockCall(address(rngAuction), abi.encodeWithSelector(rngAuction.openSequenceId.selector), abi.encode(_sequenceId));
    }

}
