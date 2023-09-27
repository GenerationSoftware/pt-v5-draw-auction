// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import { UD2x18 } from "prb-math/UD2x18.sol";
import { RNGBlockhash } from "rng/RNGBlockhash.sol";
import { PrizePool } from "pt-v5-prize-pool/PrizePool.sol";
import { RngAuction } from "../../src/RngAuction.sol";
import { RngRelayAuction } from "../../src/RngRelayAuction.sol";
import { RngAuctionRelayerDirect } from "../../src/RngAuctionRelayerDirect.sol";

contract RewardLibTest is Test {
  RNGBlockhash rng;
  PrizePool prizePool;
  RngAuction rngAuction;
  RngAuctionRelayerDirect rngAuctionRelayerDirect;
  RngRelayAuction rngRelayAuction;

  uint64 sequencePeriod = 1 days;
  uint64 sequenceOffset = 100 days;
  uint64 auctionDurationSeconds = 12 hours;
  uint64 auctionTargetTime = 30 minutes;

  address recipient1;
  address recipient2;

  function setUp() public {
    vm.warp(100 days);

    recipient1 = makeAddr("recipient1");
    recipient2 = makeAddr("recipient2");

    rng = new RNGBlockhash();

    rngAuction = new RngAuction(
      rng,
      address(this),
      sequencePeriod,
      sequenceOffset,
      auctionDurationSeconds,
      auctionTargetTime,
      UD2x18.wrap(uint64(1e18))
    );

    rngAuctionRelayerDirect = new RngAuctionRelayerDirect(rngAuction);

    prizePool = PrizePool(makeAddr("PrizePool"));

    rngRelayAuction = new RngRelayAuction(
      prizePool,
      address(rngAuctionRelayerDirect),
      auctionDurationSeconds,
      auctionTargetTime,
      10000e18
    );
  }

  function testEndToEnd() public {
    vm.warp(sequenceOffset + sequencePeriod); // warp to end of first sequence

    // trigger rng auction
    rngAuction.startRngRequest(recipient1);

    vm.roll(block.number + 2); // mine two blocks

    mockCloseDraw(uint256(blockhash(block.number - 1)));
    mockReserve(100e18);

    // no reward because it happened instantly
    // trigger relay auction
    assertEq(rngAuctionRelayerDirect.relay(rngRelayAuction, recipient2), abi.encode(1));
  }

  /** ========== MOCKS =================== */

  function mockCloseDraw(uint256 randomNumber) public {
    vm.mockCall(
      address(prizePool),
      abi.encodeWithSelector(prizePool.closeDraw.selector, randomNumber),
      abi.encodePacked(uint256(1))
    );
  }

  function mockReserve(uint256 amount) public {
    uint256 half = amount / 2;
    vm.mockCall(
      address(prizePool),
      abi.encodeWithSelector(prizePool.reserve.selector),
      abi.encode(half)
    );
    vm.mockCall(
      address(prizePool),
      abi.encodeWithSelector(prizePool.reserveForOpenDraw.selector),
      abi.encode(amount - half)
    );
  }

  function mockAllocateRewardFromReserve(address to, uint256 amount) public {
    vm.mockCall(
      address(prizePool),
      abi.encodeWithSelector(prizePool.allocateRewardFromReserve.selector, to, amount),
      abi.encode()
    );
  }
}
