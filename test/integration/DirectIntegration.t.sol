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

    uint64 sequencePeriod = 1 days;
    uint64 sequenceOffset = 100 days;
    uint64 auctionDurationSeconds = 12 hours;
    uint64 auctionTargetTime = 30 minutes;
    
    address recipient1;
    address recipient2;

    function setUp() public {
        recipient1 = makeAddr("recipient1");
        recipient2 = makeAddr("recipient2");

        rng = new RNGBlockhash();

        rngAuction = new RngAuction(
            rng,
            address(this),
            sequencePeriod,
            sequenceOffset,
            auctionDurationSeconds,
            auctionTargetTime
        );

        rngAuctionRelayerDirect = new RngAuctionRelayerDirect(
            rngAuction
        );

        prizePool = PrizePool(makeAddr("PrizePool"));

        completeRngAuction = new RngRelayAuction(
            prizePool,
            rngAuctionRelayerDirect,
            auctionDurationSeconds,
            auctionTargetTime
        );
    }


    function testEndToEnd() public {
        vm.warp(sequencePeriod); // warp to end of first sequence
        rngAuction.startRngRequest(recipient1);
        vm.warp(20 seconds); // warp one block;

        mockCloseDraw(1);
        mockReserve(100e18);
        mockWithdrawReserve(recipient1, 10e18);
        mockWithdrawReserve(recipient2, 10e18);

        rngAuctionRelayerDirect.relayRngRequest(completeRngAuction, recipient2);
    }

    /** ========== MOCKS =================== */

    function mockCloseDraw(uint256 randomNumber) public {
        vm.mockCall(
            address(prizePool),
            abi.encodeWithSelector(
                prizePool.closeDraw.selector,
                randomNumber
            ),
            abi.encode()
        );
    }

    function mockReserve(uint256 amount) public {
        vm.mockCall(
            address(prizePool),
            abi.encodeWithSelector(
                prizePool.reserve.selector
            ),
            abi.encode(amount)
        );
    }

    function mockWithdrawReserve(address to, uint256 amount) public {
        vm.mockCall(
            address(prizePool),
            abi.encodeWithSelector(
                prizePool.withdrawReserve.selector,
                to,
                amount
            ),
            abi.encode()
        );
    }

}
