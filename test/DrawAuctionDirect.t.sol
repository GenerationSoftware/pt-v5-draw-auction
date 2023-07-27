// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Helpers, RNGInterface, UD2x18, AuctionResults } from "test/helpers/Helpers.t.sol";
import { MockDrawManager } from "test/mocks/MockDrawManager.sol";

import { DrawAuctionDirect } from "local-draw-auction/DrawAuctionDirect.sol";
import { RngAuction } from "local-draw-auction/RngAuction.sol";
import { IDrawManager } from "local-draw-auction/interfaces/IDrawManager.sol";

contract DrawAuctionDirectTest is Helpers {
  /* ============ Custom Errors ============ */

  /// @notice Thrown if the DrawManager address is the zero address.
  error DrawManagerZeroAddress();

  /* ============ Mock Events ============ */

  event MockDrawManagerCloseDraw(uint256 randomNumber, AuctionResults[] results);

  /* ============ Variables ============ */

  DrawAuctionDirect public drawAuction;
  IDrawManager public drawManager;
  RngAuction public rngAuction;
  RNGInterface public rng;

  uint64 _auctionDuration = 4 hours;
  uint64 _auctionTargetTime = 2 hours;
  uint64 _rngCompletedAt = uint64(block.timestamp + 1);
  uint256 _randomNumber = 123;
  address _recipient = address(2);
  uint32 _currentSequenceId = 101;
  RngAuction.RngRequest _rngRequest =
    RngAuction.RngRequest(
      1, // rngRequestId
      uint32(block.number + 1), // lockBlock
      _currentSequenceId, // sequenceId
      0 //rngRequestedAt
    );

  function setUp() public {
    vm.warp(0);

    drawManager = new MockDrawManager();

    rngAuction = RngAuction(makeAddr("rngAuction"));
    vm.etch(address(rngAuction), "rngAuction");

    rng = RNGInterface(makeAddr("rng"));
    vm.etch(address(rng), "rng");

    drawAuction = new DrawAuctionDirect(
      drawManager,
      rngAuction,
      _auctionDuration,
      _auctionTargetTime
    );
  }

  /* ============ constructor() ============ */

  function testConstructor_DrawManagerZeroAddress() public {
    vm.expectRevert(abi.encodeWithSelector(DrawManagerZeroAddress.selector));
    new DrawAuctionDirect(
      IDrawManager(address(0)),
      rngAuction,
      _auctionDuration,
      _auctionTargetTime
    );
  }

  /* ============ Hook _afterDrawAuction() ============ */

  function testAfterDrawAuction() public {
    // Warp
    vm.warp(_rngCompletedAt + _auctionDuration); // reward fraction will be 1

    AuctionResults memory _rngAuctionResults = AuctionResults(address(this), UD2x18.wrap(0.5e18));
    AuctionResults memory _expectedAuctionResults = AuctionResults(_recipient, UD2x18.wrap(1e18));
    AuctionResults[] memory _results = new AuctionResults[](2);
    _results[0] = _rngAuctionResults;
    _results[1] = _expectedAuctionResults;

    // Mock Calls
    _mockRngAuction_isRngComplete(rngAuction, true);
    _mockRngAuction_currentSequenceId(rngAuction, _currentSequenceId);
    _mockRngAuction_getRngResults(rngAuction, _rngRequest, _randomNumber, _rngCompletedAt);
    _mockIAuction_getAuctionResults(rngAuction, _rngAuctionResults, _currentSequenceId);

    // Test
    vm.expectEmit();
    emit MockDrawManagerCloseDraw(_randomNumber, _results);
    drawAuction.completeDraw(_recipient);

    // Check results
    (AuctionResults memory _auctionResults, uint32 _sequenceId) = drawAuction.getAuctionResults();
    assertEq(_sequenceId, _currentSequenceId);
    assertEq(UD2x18.unwrap(_auctionResults.rewardFraction), uint64(1e18)); // 1
    assertEq(_auctionResults.recipient, _recipient);
  }
}
