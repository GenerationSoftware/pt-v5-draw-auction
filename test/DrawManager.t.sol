// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Helpers, RNGInterface, UD2x18, AuctionResults } from "test/helpers/Helpers.t.sol";
import { ERC20Mintable } from "./mocks/ERC20Mintable.sol";

import { DrawManager } from "local-draw-auction/DrawManager.sol";

import { PrizePool, ConstructorParams } from "pt-v5-prize-pool/PrizePool.sol";
import { TwabController } from "pt-v5-twab-controller/TwabController.sol";
import { UD2x18, ud2x18 } from "prb-math/UD2x18.sol";
import { SD1x18, sd1x18 } from "prb-math/SD1x18.sol";

import { console2 } from "forge-std/console2.sol";

contract DrawManagerTest is Helpers {
  /* ============ Custom Errors ============ */

  /// @notice Thrown if the prize pool address is the zero address.
  error PrizePoolZeroAddress();

  /* ============ Events ============ */

  /**
   * @notice Emitted when a reward for an auction is distributed to a recipient
   * @param recipient The recipient address of the reward
   * @param auctionId The ID of the auction in the sequence
   * @param reward The reward amount
   */
  event AuctionRewardDistributed(
    address indexed recipient,
    uint8 indexed auctionId,
    uint104 reward
  );

  /* ============ Prize Pool ============ */

  PrizePool public prizePool;
  ConstructorParams params;
  ERC20Mintable public prizeToken;
  TwabController public twabController;
  address public vault;
  uint64 lastClosedDrawStartedAt;
  uint32 drawPeriodSeconds;
  uint8 initialNumberOfTiers;
  uint256 winningRandomNumber = 123456;
  uint256 startTimestamp = 1000 days;

  /* ============ Variables ============ */

  address _admin = address(8675309);
  address _drawCloser = address(this);

  DrawManager public drawManager;

  address _recipient0;
  address _recipient1;

  uint256 _randomNumber = 12345;

  function setUp() public {
    vm.warp(startTimestamp);

    // Recipients
    _recipient0 = makeAddr("recipient0");
    _recipient1 = makeAddr("recipient1");

    // Prize Pool
    prizeToken = new ERC20Mintable("PoolTogether POOL token", "POOL");
    drawPeriodSeconds = 1 days;
    twabController = new TwabController(drawPeriodSeconds, uint32(block.timestamp));

    lastClosedDrawStartedAt = uint64(block.timestamp + 1 days); // set draw start 1 day into future
    initialNumberOfTiers = 3;

    params = ConstructorParams(
      prizeToken,
      twabController,
      address(0),
      drawPeriodSeconds,
      lastClosedDrawStartedAt,
      initialNumberOfTiers, // minimum number of tiers
      100,
      10,
      10,
      ud2x18(0.9e18), // claim threshold of 90%
      sd1x18(0.9e18) // alpha
    );
    prizePool = new PrizePool(params);

    // Draw Manager
    drawManager = new DrawManager(prizePool, _admin, _drawCloser);
    prizePool.setDrawManager(address(drawManager));

    vault = address(this);
  }

  /* ============ Init ============ */

  function testAdminHasRole() public {
    assertEq(drawManager.hasRole(drawManager.DEFAULT_ADMIN_ROLE(), _admin), true);
  }

  function testCloserHasRole() public {
    assertEq(drawManager.hasRole(drawManager.DRAW_CLOSER_ROLE(), _drawCloser), true);
  }

  function testPrizePoolZeroAddress() public {
    vm.expectRevert(abi.encodeWithSelector(PrizePoolZeroAddress.selector));
    new DrawManager(PrizePool(address(0)), _admin, _drawCloser);
  }

  /* ============ Prize Pool ============ */

  function testPrizePool() public {
    assertEq(address(drawManager.prizePool()), address(prizePool));
  }

  /* ============ closeDraw() ============ */

  function testCloseDraw() public {
    // Create auction results:
    AuctionResults[] memory _auctionResults = new AuctionResults[](2);
    _auctionResults[0] = AuctionResults(_recipient0, UD2x18.wrap(5e17)); // 0.5
    _auctionResults[1] = AuctionResults(_recipient1, UD2x18.wrap(1e17)); // 0.1

    // Contribute to add to reserve:
    contribute(22e19); // prize pool ends up with 1e18 reserve

    // Check recipient balances before:
    uint256 _balanceBefore0 = prizeToken.balanceOf(_recipient0);
    uint256 _balanceBefore1 = prizeToken.balanceOf(_recipient1);

    // Record draw count before:
    uint256 _drawIdBefore = prizePool.getLastClosedDrawId();

    // Test
    vm.warp(prizePool.openDrawEndsAt());
    vm.expectEmit();
    emit AuctionRewardDistributed(_recipient0, 0, 5e17);
    vm.expectEmit();
    emit AuctionRewardDistributed(_recipient1, 1, 5e16);
    drawManager.closeDraw(++_randomNumber, _auctionResults);

    assertEq(prizePool.reserve(), 45e16);
    assertEq(prizeToken.balanceOf(_recipient0), _balanceBefore0 + 5e17);
    assertEq(prizeToken.balanceOf(_recipient1), _balanceBefore1 + 5e16);

    assertEq(prizePool.getLastClosedDrawId(), _drawIdBefore + 1);
  }

  /* ============ Prize Pool Helpers============ */

  function contribute(uint256 amountContributed) public {
    contribute(amountContributed, address(this));
  }

  function contribute(uint256 amountContributed, address to) public {
    prizeToken.mint(address(prizePool), amountContributed);
    prizePool.contributePrizeTokens(to, amountContributed);
  }
}
