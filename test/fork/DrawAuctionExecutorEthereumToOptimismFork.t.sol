// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { ERC20Mock } from "openzeppelin/mocks/ERC20Mock.sol";
import { AddressAliasHelper } from "optimism/vendor/AddressAliasHelper.sol";

import { UD2x18, SD1x18, ConstructorParams, PrizePool, TieredLiquidityDistributor, TwabController } from "v5-prize-pool/PrizePool.sol";

import { DrawAuctionDispatcher, ISingleMessageDispatcher } from "../../src/DrawAuctionDispatcher.sol";
import { DrawAuctionExecutor } from "../../src/DrawAuctionExecutor.sol";
import { AuctionLib } from "../../src/libraries/AuctionLib.sol";

import { Helpers, RNGInterface } from "test/helpers/Helpers.t.sol";
import { IMessageExecutor } from "test/interfaces/IMessageExecutor.sol";
import { IL2CrossDomainMessenger } from "test/interfaces/IL2CrossDomainMessenger.sol";

contract DrawAuctionExecutorEthereumToOptimismForkTest is Helpers {
  /* ============ Events ============ */

  event AuctionRewardsDistributed(
    uint8[] phaseIds,
    address[] rewardRecipients,
    uint256[] rewardAmounts
  );

  event DrawAuctionDispatcherSet(address drawAuctionDispatcher);
  event MessageIdExecuted(uint256 indexed fromChainId, bytes32 indexed messageId);
  event WithdrawReserve(address indexed to, uint256 amount);

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
  address public mainRecipient = address(this);
  address public secondRecipient = address(3);

  /* ============ Setup ============ */

  function setUp() public {
    mainnetFork = vm.createFork(vm.rpcUrl("mainnet"));
    optimismFork = vm.createFork(vm.rpcUrl("optimism"));
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
    prizePool.setDrawManager(address(drawAuctionExecutor));
  }

  function setAll() public {
    setDrawAuctionExecutor();
    setDrawAuctionDispatcher();
    setPrizePoolDrawManager();
  }

  /* ============ Auction Execution ============ */

  function testCompleteAuctionSingleRecipient() public {
    deployAll();
    setAll();

    uint256 _reserveAmount = 200e18;
    uint256 _reserveAmountForNextDraw = _reserveAmount * 220; // Reserve amount for next draw will be 200e18

    vm.selectFork(optimismFork);

    prizeToken.mint(address(prizePool), _reserveAmountForNextDraw);
    prizePool.contributePrizeTokens(address(2), _reserveAmountForNextDraw);

    vm.selectFork(mainnetFork);

    vm.warp(block.timestamp + drawPeriodSeconds + auctionDuration / 2);

    uint32 _requestId = uint32(1);
    uint32 _lockBlock = uint32(block.number);

    _mockStartRNGRequest(address(rng), address(0), 0, _requestId, _lockBlock);

    drawAuctionDispatcher.startRNGRequest(mainRecipient);

    vm.warp(block.timestamp + drawPeriodSeconds + auctionDuration);

    _mockCompleteRNGRequest(address(rng), _requestId, randomNumber);

    drawAuctionDispatcher.completeRNGRequest(mainRecipient);

    AuctionLib.Phase[] memory _auctionPhases = new AuctionLib.Phase[](2);
    _auctionPhases[0] = drawAuctionDispatcher.getPhase(0);
    _auctionPhases[1] = drawAuctionDispatcher.getPhase(1);

    vm.selectFork(optimismFork);

    vm.warp(block.timestamp + drawPeriodSeconds + auctionDuration);

    address _to = address(drawAuctionExecutor);
    bytes memory _data = abi.encodeCall(
      DrawAuctionExecutor.completeAuction,
      (_auctionPhases, auctionDuration, randomNumber)
    );

    IL2CrossDomainMessenger l2Bridge = IL2CrossDomainMessenger(l2CrossDomainMessenger);

    address _l1CrossDomainMessengerAlias = AddressAliasHelper.applyL1ToL2Alias(
      proxyOVML1CrossDomainMessenger
    );

    vm.startPrank(_l1CrossDomainMessengerAlias);

    bytes32 _expectedMessageId = keccak256(
      abi.encode(nonce, address(drawAuctionDispatcher), _to, _data)
    );

    vm.expectEmit(address(executor));
    emit MessageIdExecuted(fromChainId, _expectedMessageId);

    l2Bridge.relayMessage(
      l2Bridge.messageNonce() + 1,
      address(dispatcher),
      address(executor),
      0,
      500_000,
      abi.encodeCall(
        IMessageExecutor.executeMessage,
        (_to, _data, _expectedMessageId, fromChainId, address(drawAuctionDispatcher))
      )
    );

    // We use assertApproxEqAbs cause we lose 1 wei in precision, probably due to a small drift in timestamp
    assertApproxEqAbs(prizeToken.balanceOf(mainRecipient), _reserveAmount, 1);
  }

  function testCompleteAuctionMultipleRecipients() public {
    deployAll();
    setAll();

    uint256 _reserveAmount = 200e18;
    uint256 _reserveAmountForNextDraw = _reserveAmount * 220; // Reserve amount for next draw will be 200e18

    vm.selectFork(optimismFork);

    prizeToken.mint(address(prizePool), _reserveAmountForNextDraw);
    prizePool.contributePrizeTokens(address(2), _reserveAmountForNextDraw);

    vm.selectFork(mainnetFork);

    vm.warp(block.timestamp + drawPeriodSeconds + auctionDuration / 2);

    uint32 _requestId = uint32(1);
    uint32 _lockBlock = uint32(block.number);

    _mockStartRNGRequest(address(rng), address(0), 0, _requestId, _lockBlock);

    drawAuctionDispatcher.startRNGRequest(mainRecipient);

    vm.warp(block.timestamp + drawPeriodSeconds + auctionDuration);

    _mockCompleteRNGRequest(address(rng), _requestId, randomNumber);

    drawAuctionDispatcher.completeRNGRequest(secondRecipient);

    AuctionLib.Phase[] memory _auctionPhases = new AuctionLib.Phase[](2);
    _auctionPhases[0] = drawAuctionDispatcher.getPhase(0);
    _auctionPhases[1] = drawAuctionDispatcher.getPhase(1);

    vm.selectFork(optimismFork);

    vm.warp(block.timestamp + drawPeriodSeconds + auctionDuration);

    address _to = address(drawAuctionExecutor);
    bytes memory _data = abi.encodeCall(
      DrawAuctionExecutor.completeAuction,
      (_auctionPhases, auctionDuration, randomNumber)
    );

    IL2CrossDomainMessenger l2Bridge = IL2CrossDomainMessenger(l2CrossDomainMessenger);

    address _l1CrossDomainMessengerAlias = AddressAliasHelper.applyL1ToL2Alias(
      proxyOVML1CrossDomainMessenger
    );

    vm.startPrank(_l1CrossDomainMessengerAlias);

    bytes32 _expectedMessageId = keccak256(
      abi.encode(nonce, address(drawAuctionDispatcher), _to, _data)
    );

    vm.expectEmit(address(executor));
    emit MessageIdExecuted(fromChainId, _expectedMessageId);

    l2Bridge.relayMessage(
      l2Bridge.messageNonce() + 1,
      address(dispatcher),
      address(executor),
      0,
      500_000,
      abi.encodeCall(
        IMessageExecutor.executeMessage,
        (_to, _data, _expectedMessageId, fromChainId, address(drawAuctionDispatcher))
      )
    );

    // We use assertApproxEqAbs cause we lose 1 wei in precision, probably due to a small drift in timestamp
    assertApproxEqAbs(
      prizeToken.balanceOf(mainRecipient) + prizeToken.balanceOf(secondRecipient),
      _reserveAmount,
      1
    );
  }

  /* ============ Getters ============ */

  function testGetters() public {
    deployAll();
    setAll();

    assertEq(drawAuctionExecutor.originChainId(), fromChainId);
    assertEq(drawAuctionExecutor.drawAuctionDispatcher(), address(drawAuctionDispatcher));
    assertEq(address(drawAuctionExecutor.prizePool()), address(prizePool));
  }

  /* ============ Setters ============ */

  /* ============ setDrawAuctionDispatcher ============ */
  function testSetDrawAuctionDispatcher() public {
    deployAll();

    vm.expectEmit();
    emit DrawAuctionDispatcherSet(address(drawAuctionDispatcher));

    drawAuctionExecutor.setDrawAuctionDispatcher(address(drawAuctionDispatcher));

    assertEq(drawAuctionExecutor.drawAuctionDispatcher(), address(drawAuctionDispatcher));
  }

  function testSetDrawAuctionDispatcherFailAlreadySet() public {
    deployAll();
    setAll();

    vm.expectRevert(
      abi.encodeWithSelector(DrawAuctionExecutor.DrawAuctionDispatcherAlreadySet.selector)
    );
    drawAuctionExecutor.setDrawAuctionDispatcher(address(drawAuctionDispatcher));
  }

  function testSetDrawAuctionDispatcherFailAddressZero() public {
    deployAll();

    vm.expectRevert(
      abi.encodeWithSelector(DrawAuctionExecutor.DrawAuctionDispatcherZeroAddress.selector)
    );
    drawAuctionExecutor.setDrawAuctionDispatcher(address(0));
  }
}
