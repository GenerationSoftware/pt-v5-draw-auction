// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import { UD2x18 } from "prb-math/UD2x18.sol";
import { RNGInterface } from "rng/RNGInterface.sol";
import { PrizePool } from "pt-v5-prize-pool/PrizePool.sol";
import { StartRngAuction } from "../../src/StartRngAuction.sol";
import { CompleteRngAuction } from "../../src/CompleteRngAuction.sol";
import { RngAuctionRelayerDirect } from "../../src/RngAuctionRelayerDirect.sol";

contract RewardLibTest is Test {

    // RNGInterface rng;
    // PrizePool prizePool;

    // uint64 sequencePeriod = 1 days;
    // uint64 sequenceOffset = 100 days;
    // uint64 auctionDurationSeconds = 12 hours;
    // uint64 auctionTargetTime = 30 minutes;

    // function setUp() public {
    //     rng = RNGInterface(makeAddr("RNGInterface"));

    //     startRngAuction = new StartRngAuction(
    //         rng,
    //         address(this),
    //         sequencePeriod,
    //         sequenceOffset,
    //         auctionDurationSeconds,
    //         auctionTargetTime
    //     );

    //     rngAuctionRelayerDirect = new RngAuctionRelayerDirect(
    //         startRngAuction
    //     );

    //     // drawManager = new DrawManager(prizePool, address(this), address drawCloser_);

    //     // completeRngAuction = new CompleteRngAuction(
    //     //     DrawManager drawManager_,
    //     //     address _startRngAuctionRelayer,
    //     //     uint64 auctionDurationSeconds_,
    //     //     uint64 auctionTargetTime_
    //     // )

    //     prizePool = PrizePool(makeAddr("PrizePool"));
    // }

}
