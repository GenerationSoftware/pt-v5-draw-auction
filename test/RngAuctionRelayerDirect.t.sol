// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import { UD2x18 } from "prb-math/UD2x18.sol";
import { RngAuction } from "../src/RngAuction.sol";
import { IRngAuctionRelayListener } from "../src/interfaces/IRngAuctionRelayListener.sol";
import { AuctionResult } from "../src/interfaces/IAuction.sol";

import { RngRelayerBaseTest } from "./helpers/RngRelayerBaseTest.sol";

import { RngNotCompleted } from "../src/abstract/RngAuctionRelayer.sol";

import {
  RngAuctionRelayerDirect,
  RngAuctionIsZeroAddress,
  DirectRelayFailed,
  PrizePool
} from "../src/RngAuctionRelayerDirect.sol";

contract RngAuctionRelayerDirectTest is RngRelayerBaseTest {
  event DirectRelaySuccess(address indexed rewardRecipient, bytes returnData);

  RngAuctionRelayerDirect relayer;

  PrizePool prizePool;

  function setUp() public override {
    super.setUp();
    prizePool = PrizePool(makeAddr("prizePool"));
    relayer = new RngAuctionRelayerDirect(rngAuction);
  }

  function testConstructor() public {
    assertEq(address(relayer.rngAuction()), address(rngAuction));
  }

  function testConstructor_RngAuctionIsZeroAddress() public {
    vm.expectRevert(abi.encodeWithSelector(RngAuctionIsZeroAddress.selector));
    new RngAuctionRelayerDirect(RngAuction(address(0)));
  }

  function testDirectRelay_happyPath() public {
    mockIsRngComplete(true);
    mockRngResults(123, 456);
    mockAuctionResult(address(this), UD2x18.wrap(0.5 ether));
    mockCurrentSequenceId(789);

    vm.mockCall(
      address(rngAuctionRelayListener),
      abi.encodeWithSelector(
        rngAuctionRelayListener.rngComplete.selector,
        prizePool,
        123,
        456,
        address(this),
        789,
        AuctionResult(address(this), UD2x18.wrap(0.5 ether))
      ),
      abi.encode(42)
    );

    vm.expectEmit(true, true, false, false);

    emit DirectRelaySuccess(address(this), abi.encode(42));
    assertEq(relayer.relay(rngAuctionRelayListener, prizePool, address(this)), abi.encode(42));
  }

  function testDirectRelay_callRevert() public {
    mockIsRngComplete(true);
    mockRngResults(123, 456);
    mockAuctionResult(address(this), UD2x18.wrap(0.5 ether));
    mockCurrentSequenceId(789);

    vm.mockCallRevert(
      address(rngAuctionRelayListener),
      abi.encodeWithSelector(
        rngAuctionRelayListener.rngComplete.selector,
        prizePool,
        123,
        456,
        address(this),
        789,
        AuctionResult(address(this), UD2x18.wrap(0.5 ether))
      ),
      abi.encode("this is bad")
    );

    vm.expectRevert(abi.encodeWithSelector(DirectRelayFailed.selector, abi.encode("this is bad")));
    relayer.relay(rngAuctionRelayListener, prizePool, address(this));
  }

  function testDirectRelay_RngNotCompleted() public {
    mockIsRngComplete(false);
    vm.expectRevert(abi.encodeWithSelector(RngNotCompleted.selector));
    relayer.relay(rngAuctionRelayListener, prizePool, address(this));
  }
}
