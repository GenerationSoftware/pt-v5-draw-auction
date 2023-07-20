// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Helpers, RNGInterface, UD2x18, AuctionResults } from "test/helpers/Helpers.t.sol";

import { RngAuction } from "local-draw-auction/RngAuction.sol";

contract RngAuctionTest is Helpers {
  /* ============ Events ============ */

  event AuctionCompleted(
    address indexed recipient,
    uint32 indexed sequenceId,
    uint64 elapsedTime,
    UD2x18 rewardPortion
  );

  /* ============ Variables ============ */

  RngAuction public rngAuction;
  RNGInterface public rng;

  uint64 _auctionDuration = 3 hours;
  uint64 _sequencePeriodSeconds = 1 days;
  uint64 _sequenceOffsetSeconds = 0;
  address _recipient = address(2);

  function setUp() public {
    vm.warp(0);

    rng = RNGInterface(makeAddr("rng"));
    vm.etch(address(rng), "rng");

    rngAuction = new RngAuction(
      rng,
      address(this),
      _sequencePeriodSeconds,
      _sequenceOffsetSeconds,
      _auctionDuration
    );
  }

  /* ============ currentSequenceId() ============ */

  function testCurrentSequence() public {
    vm.warp(0);
    assertEq(rngAuction.currentSequenceId(), 0);
    vm.warp(_sequencePeriodSeconds - 1);
    assertEq(rngAuction.currentSequenceId(), 0);

    vm.warp(_sequencePeriodSeconds);
    assertEq(rngAuction.currentSequenceId(), 1);
    vm.warp(_sequencePeriodSeconds * 2 - 1);
    assertEq(rngAuction.currentSequenceId(), 1);
  }

  function testCurrentSequence_WithOffset() public {
    uint64 _offset = 101;
    RngAuction offsetRngAuction = new RngAuction(
      rng,
      address(this),
      _sequencePeriodSeconds,
      _offset,
      _auctionDuration
    );

    vm.warp(_offset);
    assertEq(offsetRngAuction.currentSequenceId(), 0);
    vm.warp(_offset + _sequencePeriodSeconds - 1);
    assertEq(offsetRngAuction.currentSequenceId(), 0);

    vm.warp(_offset + _sequencePeriodSeconds);
    assertEq(offsetRngAuction.currentSequenceId(), 1);
    vm.warp(_offset + _sequencePeriodSeconds * 2 - 1);
    assertEq(offsetRngAuction.currentSequenceId(), 1);
  }

  function testFailCurrentSequence_BeforeOffset() public {
    uint64 _offset = 101;
    RngAuction offsetRngAuction = new RngAuction(
      rng,
      address(this),
      _sequencePeriodSeconds,
      _offset,
      _auctionDuration
    );

    vm.warp(_offset - 1);
    offsetRngAuction.currentSequenceId();
  }

  /* ============ startRngRequest() ============ */

  function testStartRngRequest() public {
    // Warp to halfway through auction
    vm.warp(_sequencePeriodSeconds + _auctionDuration / 2);

    // Variables
    uint32 _rngRequestId = 1;
    uint32 _lockBlock = uint32(block.number);

    // Mock calls
    _mockRngAuction_startRngRequest(rng, address(0), 0, _rngRequestId, _lockBlock);

    // Tests
    uint64 _requestedAt = uint64(block.timestamp);

    vm.expectEmit();
    emit AuctionCompleted(_recipient, 1, _auctionDuration / 2, UD2x18.wrap(uint64(5e17)));

    rngAuction.startRngRequest(_recipient);
    (AuctionResults memory _auctionResults, uint32 _sequenceId) = rngAuction.getAuctionResults();
    RngAuction.RngRequest memory _rngRequest = rngAuction.getRngRequest();

    assertEq(_sequenceId, 1);

    assertEq(_auctionResults.recipient, _recipient);
    assertEq(UD2x18.unwrap(_auctionResults.rewardPortion), 5e17);

    assertEq(_rngRequest.id, _rngRequestId);
    assertEq(_rngRequest.lockBlock, _lockBlock);
    assertEq(_rngRequest.sequenceId, 1);
    assertEq(_rngRequest.requestedAt, _requestedAt);
  }
}
