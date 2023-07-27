// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import "openzeppelin/utils/Strings.sol";

import { MockDispatcher } from "test/mocks/MockDispatcher.sol";

import { DrawManagerAdapterHarness } from "test/harness/DrawManagerAdapterHarness.sol";
import { ISingleMessageDispatcher } from "local-draw-auction/interfaces/ISingleMessageDispatcher.sol";
import { AuctionResults } from "local-draw-auction/interfaces/IAuction.sol";

contract DrawManagerAdapterTest is Test {
  /* ============ Events ============ */

  /**
   * @notice Event emitted when the random number and auction results have been dispatched.
   * @param dispatcher Instance of the dispatcher on Ethereum that dispatched the message
   * @param toChainId ID of the receiving chain
   * @param drawManagerReceiver Address of the DrawManagerReceiver on the receiving chain that will award the auctions and complete the Draw
   * @param randomNumber Random number computed by the RNG
   * @param auctionResults Array of auction results
   */
  event MessageDispatched(
    ISingleMessageDispatcher indexed dispatcher,
    uint256 indexed toChainId,
    address indexed drawManagerReceiver,
    uint256 randomNumber,
    AuctionResults[] auctionResults
  );

  /* ============ Custom Errors ============ */

  /// @notice Thrown when the Dispatcher address passed to the constructor is zero address.
  error DispatcherZeroAddress();

  /// @notice Thrown when the toChainId passed to the constructor is zero.
  error ToChainIdZero();

  /// @notice Thrown when the DrawManagerReceiver address passed to the constructor is zero address.
  error DrawManagerReceiverZeroAddress();

  /* ============ Variables ============ */

  DrawManagerAdapterHarness public drawManagerAdapter;

  ISingleMessageDispatcher public dispatcher;
  address public drawManagerReceiver;
  uint256 public toChainId;
  address public admin;
  address public drawCloser;

  /* ============ Set Up ============ */

  function setUp() public {
    dispatcher = new MockDispatcher();
    drawManagerReceiver = address(2);
    toChainId = 10;
    admin = address(3);
    drawCloser = address(4);
    drawManagerAdapter = new DrawManagerAdapterHarness(
      dispatcher,
      drawManagerReceiver,
      toChainId,
      admin,
      drawCloser
    );
  }

  /* ============ Constructor ============ */

  function testConstructor_DispatcherZeroAddress() public {
    vm.expectRevert(abi.encodeWithSelector(DispatcherZeroAddress.selector));
    drawManagerAdapter = new DrawManagerAdapterHarness(
      ISingleMessageDispatcher(address(0)),
      drawManagerReceiver,
      toChainId,
      admin,
      drawCloser
    );
  }

  function testConstructor_DrawManagerReceiverZeroAddress() public {
    vm.expectRevert(abi.encodeWithSelector(DrawManagerReceiverZeroAddress.selector));
    drawManagerAdapter = new DrawManagerAdapterHarness(
      dispatcher,
      address(0),
      toChainId,
      admin,
      drawCloser
    );
  }

  function testConstructor_ToChainIdZero() public {
    vm.expectRevert(abi.encodeWithSelector(ToChainIdZero.selector));
    drawManagerAdapter = new DrawManagerAdapterHarness(
      dispatcher,
      drawManagerReceiver,
      0,
      admin,
      drawCloser
    );
  }

  /* ============ setDispatcher() ============ */

  function testSetDispatcher() public {
    drawManagerAdapter.setDispatcher(ISingleMessageDispatcher(address(2345)));
    assertEq(address(drawManagerAdapter.dispatcher()), address(2345));
  }

  function testSetDispatcher_DispatcherZeroAddress() public {
    vm.expectRevert(abi.encodeWithSelector(DispatcherZeroAddress.selector));
    drawManagerAdapter.setDispatcher(ISingleMessageDispatcher(address(0)));
  }

  /* ============ setDrawManagerReceiver() ============ */

  function testSetDrawManagerReceiver() public {
    drawManagerAdapter.setDrawManagerReceiver(address(23456));
    assertEq(address(drawManagerAdapter.drawManagerReceiver()), address(23456));
  }

  function testSetDrawManagerReceiver_DrawManagerReceiverZeroAddress() public {
    vm.expectRevert(abi.encodeWithSelector(DrawManagerReceiverZeroAddress.selector));
    drawManagerAdapter.setDrawManagerReceiver(address(0));
  }

  /* ============ dispatcher() ============ */

  function testDispatcher() public {
    assertEq(address(drawManagerAdapter.dispatcher()), address(dispatcher));
  }

  /* ============ drawManagerReceiver() ============ */

  function testDrawManagerReceiver() public {
    assertEq(drawManagerAdapter.drawManagerReceiver(), drawManagerReceiver);
  }

  /* ============ toChainId() ============ */

  function testToChainId() public {
    assertEq(drawManagerAdapter.toChainId(), toChainId);
  }

  /* ============ closeDraw() ============ */

  function testCloseDraw() public {
    AuctionResults[] memory _results = new AuctionResults[](2);
    uint256 _randomNumber = 12345;

    vm.expectEmit();
    emit MessageDispatched(dispatcher, toChainId, drawManagerReceiver, _randomNumber, _results);

    vm.startPrank(drawCloser);
    drawManagerAdapter.closeDraw(_randomNumber, _results);
    vm.stopPrank();
  }

  function testCloseDraw_RevertIfNotDrawCloser() public {
    AuctionResults[] memory _results = new AuctionResults[](2);
    vm.expectRevert(
      abi.encodePacked(
        "AccessControl: account ",
        Strings.toHexString(address(this)),
        " is missing role ",
        Strings.toHexString(uint256(drawManagerAdapter.DRAW_CLOSER_ROLE()), 32)
      )
    );
    drawManagerAdapter.closeDraw(123, _results);
  }

  function testCloseDraw_Remapping() public {
    AuctionResults[] memory _results = new AuctionResults[](2);
    _results[0].recipient = address(1);
    _results[1].recipient = address(2);

    AuctionResults[] memory _resultsRemapped = new AuctionResults[](2);
    _resultsRemapped[0].recipient = address(3);
    _resultsRemapped[1].recipient = address(4);

    vm.startPrank(address(1));
    drawManagerAdapter.remapTo(address(3));
    vm.stopPrank();

    vm.startPrank(address(2));
    drawManagerAdapter.remapTo(address(4));
    vm.stopPrank();

    uint256 _randomNumber = 12345;

    vm.expectEmit();
    emit MessageDispatched(
      dispatcher,
      toChainId,
      drawManagerReceiver,
      _randomNumber,
      _resultsRemapped // remapped results!!!
    );

    vm.startPrank(drawCloser);
    drawManagerAdapter.closeDraw(_randomNumber, _results);
    vm.stopPrank();
  }
}
