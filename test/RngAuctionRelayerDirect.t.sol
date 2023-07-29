// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import { UD2x18 } from "prb-math/UD2x18.sol";
import { RngAuction } from "../src/RngAuction.sol";
import { IRngAuctionRelayListener } from "../src/interfaces/IRngAuctionRelayListener.sol";
import { AuctionResults } from "../src/interfaces/IAuction.sol";

import { RngRelayerBaseTest } from "./helpers/RngRelayerBaseTest.sol";

import { RngNotCompleted } from "../src/abstract/RngAuctionRelayer.sol";

import {
    RngAuctionRelayerDirect,
    DirectRelayFailed
} from "../src/RngAuctionRelayerDirect.sol";

contract RngAuctionRelayerDirectTest is RngRelayerBaseTest {

    event DirectRelaySuccess(address indexed rewardRecipient, bytes returnData);

    RngAuctionRelayerDirect relayer;


    function setUp() public override {
        super.setUp();
        relayer = new RngAuctionRelayerDirect(startRngAuction);
    }

    function testConstructor() public {
        assertEq(address(relayer.startRngAuction()), address(startRngAuction));
    }

    function testDirectRelay_happyPath() public {

        mockIsRngComplete(true);
        mockRngResults(123, 456);
        mockAuctionResults(address(this), UD2x18.wrap(0.5 ether));
        mockCurrentSequenceId(789);

        vm.mockCall(
            address(rngAuctionRelayListener),
            abi.encodeWithSelector(rngAuctionRelayListener.rngComplete.selector, 123, 456, address(this), 789, AuctionResults(address(this), UD2x18.wrap(0.5 ether))),
            abi.encode(42)
        );

        vm.expectEmit(true, true, false, false);

        emit DirectRelaySuccess(address(this), abi.encode(42));
        assertEq(relayer.relay(rngAuctionRelayListener, address(this)), abi.encode(42));
    }

    function testDirectRelay_callRevert() public {

        mockIsRngComplete(true);
        mockRngResults(123, 456);
        mockAuctionResults(address(this), UD2x18.wrap(0.5 ether));
        mockCurrentSequenceId(789);

        vm.mockCallRevert(
            address(rngAuctionRelayListener),
            abi.encodeWithSelector(rngAuctionRelayListener.rngComplete.selector, 123, 456, address(this), 789, AuctionResults(address(this), UD2x18.wrap(0.5 ether))),
            abi.encode("this is bad")
        );

        vm.expectRevert(abi.encodeWithSelector(DirectRelayFailed.selector, abi.encode("this is bad")));
        relayer.relay(rngAuctionRelayListener, address(this));
    }

    function testDirectRelay_RngNotCompleted() public {
        mockIsRngComplete(false);
        vm.expectRevert(abi.encodeWithSelector(RngNotCompleted.selector));
        relayer.relay(rngAuctionRelayListener, address(this));
    }

}
