// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { ERC20Mock } from "openzeppelin/mocks/ERC20Mock.sol";

import { UD2x18, SD1x18, ConstructorParams, PrizePool, TieredLiquidityDistributor, TwabController } from "v5-prize-pool/PrizePool.sol";

import { DrawAuctionDispatcher, ISingleMessageDispatcher } from "../../src/DrawAuctionDispatcher.sol";
import { DrawAuctionExecutor } from "../../src/DrawAuctionExecutor.sol";
import { AuctionLib } from "../../src/libraries/AuctionLib.sol";

import { Helpers, RNGInterface } from "test/helpers/Helpers.t.sol";

contract DrawAuctionDispatcherEthereumToOptimismForkTest is Helpers {
  /* ============ Events ============ */

  event DispatcherSet(ISingleMessageDispatcher indexed dispatcher);
  event DrawAuctionExecutorSet(address indexed drawAuctionExecutor);

  event AuctionDispatched(
    ISingleMessageDispatcher indexed dispatcher,
    uint256 indexed toChainId,
    address indexed drawAuctionExecutor,
    AuctionLib.Phase[] phases,
    uint256 randomNumber
  );

  /* ============ Variables ============ */

  uint256 public mainnetFork;
  uint256 public optimismFork;

  address public proxyOVML1CrossDomainMessenger = 0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1;
  address public l2CrossDomainMessenger = 0x4200000000000000000000000000000000000007;

  uint256 public nonce = 1;
  uint256 public toChainId = 10;
  uint256 public fromChainId = 1;

  ISingleMessageDispatcher public dispatcher =
    ISingleMessageDispatcher(address(0xa8f85bAB964D7e6bE938B54Bf4b29A247A88CD9d));
  address public executor = 0x890a87E71E731342a6d10e7628bd1F0733ce3296;

  DrawAuctionDispatcher public drawAuctionDispatcher;
  DrawAuctionExecutor public drawAuctionExecutor;

  ERC20Mock public prizeToken;
  PrizePool public prizePool;
  RNGInterface public rng = RNGInterface(address(1));

  uint32 public auctionDuration = 3 hours;
  uint32 public rngTimeOut = 1 hours;
  uint32 public drawPeriodSeconds = 1 days;
  uint256 public randomNumber = 123456789;
  address public recipient = address(this);

  /* ============ Setup ============ */

  function setUp() public {
    mainnetFork = vm.createFork(vm.rpcUrl("mainnet"));
    optimismFork = vm.createFork(vm.rpcUrl("optimism"));

    vm.warp(0);
  }

  function deployDrawAuctionDispatcher() public {
    vm.selectFork(mainnetFork);

    drawAuctionDispatcher = new DrawAuctionDispatcher(
      dispatcher,
      toChainId,
      rng,
      rngTimeOut,
      2,
      auctionDuration,
      address(this)
    );

    vm.makePersistent(address(drawAuctionDispatcher));
  }

  function deployDrawAuctionExecutor() public {
    vm.selectFork(optimismFork);

    drawAuctionExecutor = new DrawAuctionExecutor(fromChainId, executor, prizePool);

    vm.makePersistent(address(drawAuctionExecutor));
  }

  function deployPrizePool() public {
    vm.selectFork(optimismFork);

    prizeToken = new ERC20Mock();

    prizePool = new PrizePool(
      ConstructorParams({
        prizeToken: prizeToken,
        twabController: TwabController(address(0)),
        drawManager: address(0),
        drawPeriodSeconds: drawPeriodSeconds,
        firstDrawStartsAt: uint64(block.timestamp),
        numberOfTiers: uint8(3), // minimum number of tiers
        tierShares: 100,
        canaryShares: 10,
        reserveShares: 10,
        claimExpansionThreshold: UD2x18.wrap(0.9e18), // claim threshold of 90%
        smoothing: SD1x18.wrap(0.9e18) // alpha
      })
    );

    vm.makePersistent(address(prizePool));
  }

  function deployAll() public {
    deployDrawAuctionDispatcher();
    deployPrizePool();
    deployDrawAuctionExecutor();
  }

  function setDrawAuctionExecutor() public {
    vm.selectFork(mainnetFork);
    drawAuctionDispatcher.setDrawAuctionExecutor(address(drawAuctionExecutor));
  }

  function setDrawAuctionDispatcher() public {
    vm.selectFork(optimismFork);
    drawAuctionExecutor.setDrawAuctionDispatcher(address(drawAuctionDispatcher));
  }

  function setPrizePoolDrawManager() public {
    vm.selectFork(optimismFork);
    prizePool.setDrawManager(address(drawAuctionDispatcher));
  }

  function setAll() public {
    setDrawAuctionExecutor();
    setDrawAuctionDispatcher();
    setPrizePoolDrawManager();
  }

  /* ============ Auction Dispatch ============ */
  function testAfterAuctionEnds() public {
    deployAll();
    setAll();

    vm.selectFork(mainnetFork);

    vm.warp(drawPeriodSeconds + auctionDuration / 2);

    uint32 _requestId = uint32(1);
    uint32 _lockBlock = uint32(block.number);

    _mockStartRNGRequest(address(rng), address(0), 0, _requestId, _lockBlock);

    drawAuctionDispatcher.startRNGRequest(recipient);

    uint64 _warpTimestamp = uint64(drawPeriodSeconds + auctionDuration);
    vm.warp(_warpTimestamp);

    _mockCompleteRNGRequest(address(rng), _requestId, randomNumber);

    AuctionLib.Phase[] memory _auctionPhases = new AuctionLib.Phase[](2);
    _auctionPhases[0] = drawAuctionDispatcher.getPhase(0);
    _auctionPhases[1] = _getPhase(1, _auctionPhases[0].endTime, _warpTimestamp, recipient);

    vm.expectEmit();
    emit AuctionDispatched(
      drawAuctionDispatcher.dispatcher(),
      drawAuctionDispatcher.toChainId(),
      drawAuctionDispatcher.drawAuctionExecutor(),
      _auctionPhases,
      randomNumber
    );

    drawAuctionDispatcher.completeRNGRequest(recipient);
  }

  /* ============ Getters ============ */

  function testGetters() public {
    deployAll();
    setAll();

    assertEq(address(drawAuctionDispatcher.dispatcher()), address(dispatcher));
    assertEq(drawAuctionDispatcher.drawAuctionExecutor(), address(drawAuctionExecutor));
    assertEq(drawAuctionDispatcher.toChainId(), toChainId);
  }

  /* ============ Setters ============ */

  /* ============ setDispatcher ============ */
  function testSetDispatcher() public {
    deployAll();
    setAll();

    ISingleMessageDispatcher _dispatcher = ISingleMessageDispatcher(address(2));

    vm.expectEmit();
    emit DispatcherSet(_dispatcher);

    drawAuctionDispatcher.setDispatcher(_dispatcher);

    assertEq(address(drawAuctionDispatcher.dispatcher()), address(_dispatcher));
  }

  function testSetDispatcherFailAddressZero() public {
    deployAll();
    setAll();

    ISingleMessageDispatcher _dispatcher = ISingleMessageDispatcher(address(0));

    vm.expectRevert(abi.encodeWithSelector(DrawAuctionDispatcher.DispatcherZeroAddress.selector));
    drawAuctionDispatcher.setDispatcher(_dispatcher);
  }

  function testSetDispatcherFailNotOwner() public {
    deployAll();
    setAll();

    ISingleMessageDispatcher _dispatcher = ISingleMessageDispatcher(address(2));

    vm.startPrank(address(4));

    vm.expectRevert(bytes("Ownable/caller-not-owner"));
    drawAuctionDispatcher.setDispatcher(_dispatcher);
  }

  /* ============ setDrawAuctionExecutor ============ */
  function testSetDrawAuctionExecutor() public {
    deployAll();
    setAll();

    address _drawAuctionExecutor = address(3);

    vm.expectEmit();
    emit DrawAuctionExecutorSet(_drawAuctionExecutor);

    drawAuctionDispatcher.setDrawAuctionExecutor(_drawAuctionExecutor);

    assertEq(address(drawAuctionDispatcher.drawAuctionExecutor()), address(_drawAuctionExecutor));
  }

  function testSetDrawAuctionExecutorFailAddressZero() public {
    deployAll();
    setAll();

    ISingleMessageDispatcher _dispatcher = ISingleMessageDispatcher(address(0));

    vm.expectRevert(abi.encodeWithSelector(DrawAuctionDispatcher.DispatcherZeroAddress.selector));
    drawAuctionDispatcher.setDispatcher(_dispatcher);
  }

  function testSetDrawAuctionExecutorFailNotOwner() public {
    deployAll();
    setAll();

    ISingleMessageDispatcher _dispatcher = ISingleMessageDispatcher(address(3));

    vm.startPrank(address(4));

    vm.expectRevert(bytes("Ownable/caller-not-owner"));
    drawAuctionDispatcher.setDispatcher(_dispatcher);
  }
}
