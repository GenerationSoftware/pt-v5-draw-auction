// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { ERC20Mock } from "openzeppelin/mocks/ERC20Mock.sol";

import { RNGRequestor } from "src/abstract/RNGRequestor.sol";
import { Helpers, RNGInterface } from "./helpers/Helpers.t.sol";

contract RNGRequestorTest is Helpers {
  /* ============ Events ============ */

  event RNGServiceSet(RNGInterface indexed rngService);
  event RNGTimeoutSet(uint32 rngTimeout);
  event RNGRequestStarted(uint32 indexed rngRequestId, uint32 rngLockBlock);
  event RNGRequestCompleted(uint32 indexed rngRequestId, uint256 randomNumber);
  event RNGRequestCancelled(uint32 indexed rngRequestId, uint32 rngLockBlock);

  /* ============ Variables ============ */

  RNGInterface public rng;
  RNGRequestor public rngRequestor;
  uint32 public rngTimeOut = 1 hours;

  ERC20Mock public feeToken;
  uint256 public feeAmount;
  address public recipient = address(this);

  function setUp() public {
    feeToken = new ERC20Mock();
    feeAmount = 2e18;

    rng = RNGInterface(address(1));

    rngRequestor = new RNGRequestor(rng, rngTimeOut, address(this));
  }

  /* ============ Constructor ============ */

  function testConstructor() public {
    assertEq(address(rngRequestor.getRNGService()), address(rng));
    assertEq(rngRequestor.getRNGTimeout(), rngTimeOut);
    assertEq(rngRequestor.owner(), address(this));
  }

  /* ============ Methods ============ */

  /* ============ startRNGRequest ============ */
  function testStartRNGRequest() public {
    uint32 _requestId = uint32(1);
    uint32 _lockBlock = uint32(block.number);

    _mockStartRNGRequest(address(rng), address(0), 0, _requestId, _lockBlock);

    vm.expectEmit();
    emit RNGRequestStarted(_requestId, _lockBlock);

    rngRequestor.startRNGRequest(recipient);

    assertEq(rngRequestor.getRNGLockBlock(), _lockBlock);
    assertEq(rngRequestor.getRNGRequestId(), _requestId);
  }

  // @TODO Test with ChainlinkVRFV2 direct LINK transfer contract
  function testStartRNGRequestWithFeeToken() public {
    uint32 _requestId = uint32(1);
    uint32 _lockBlock = uint32(block.number);

    _mockStartRNGRequest(address(rng), address(feeToken), feeAmount, _requestId, _lockBlock);

    vm.expectEmit();
    emit RNGRequestStarted(_requestId, _lockBlock);

    rngRequestor.startRNGRequest(recipient);

    assertEq(rngRequestor.getRNGLockBlock(), _lockBlock);
    assertEq(rngRequestor.getRNGRequestId(), _requestId);
  }

  function testStartRNGRequestFailRNGRequested() public {
    uint32 _requestId = uint32(1);
    uint32 _lockBlock = uint32(block.number);

    _mockStartRNGRequest(address(rng), address(0), 0, _requestId, _lockBlock);

    rngRequestor.startRNGRequest(recipient);

    vm.expectRevert(abi.encodeWithSelector(RNGRequestor.RNGRequested.selector, _requestId));

    rngRequestor.startRNGRequest(recipient);
  }

  /* ============ completeRNGRequest ============ */
  function testCompleteRNGRequest() public {
    uint32 _requestId = uint32(1);
    uint32 _lockBlock = uint32(block.number);
    uint256 _randomNumber = 123456789;

    _mockStartRNGRequest(address(rng), address(0), 0, _requestId, _lockBlock);

    rngRequestor.startRNGRequest(recipient);

    _mockIsRequestComplete(address(rng), _requestId, true);
    _mockRandomNumber(address(rng), _requestId, _randomNumber);
    _mockCompletedAt(address(rng), _requestId, uint64(block.timestamp));

    vm.expectEmit();
    emit RNGRequestCompleted(_requestId, _randomNumber);

    rngRequestor.completeRNGRequest(recipient);
  }

  function testCompleteRNGRequestFailRNGNotRequested() public {
    vm.expectRevert(abi.encodeWithSelector(RNGRequestor.RNGNotRequested.selector));

    rngRequestor.completeRNGRequest(recipient);
  }

  function testCompleteRNGRequestFailRNGNotCompleted() public {
    uint32 _requestId = uint32(1);
    uint32 _lockBlock = uint32(block.number);

    _mockStartRNGRequest(address(rng), address(0), 0, _requestId, _lockBlock);

    rngRequestor.startRNGRequest(recipient);

    _mockIsRequestComplete(address(rng), _requestId, false);

    vm.expectRevert(abi.encodeWithSelector(RNGRequestor.RNGNotCompleted.selector, _requestId));

    rngRequestor.completeRNGRequest(recipient);
  }

  /* ============ cancelRNGRequest ============ */
  function testCancelRNGRequest() public {
    uint32 _requestId = uint32(1);
    uint32 _lockBlock = uint32(block.number);

    _mockStartRNGRequest(address(rng), address(0), 0, _requestId, _lockBlock);

    rngRequestor.startRNGRequest(recipient);

    vm.warp(2 hours);

    vm.expectEmit();
    emit RNGRequestCancelled(_requestId, _lockBlock);

    rngRequestor.cancelRNGRequest();
  }

  function testCancelRNGRequestFail() public {
    uint32 _requestId = uint32(1);
    uint32 _lockBlock = uint32(block.number);

    _mockStartRNGRequest(address(rng), address(0), 0, _requestId, _lockBlock);

    rngRequestor.startRNGRequest(recipient);

    vm.expectRevert(abi.encodeWithSelector(RNGRequestor.RNGHasNotTimedout.selector));

    rngRequestor.cancelRNGRequest();
  }

  /* ============ State Functions ============ */

  /* ============ isRNGRequested ============ */
  function testIsRNGRequestedDefaultState() public {
    assertEq(rngRequestor.isRNGRequested(), false);
  }

  function testIsRNGRequestedActiveState() public {
    uint32 _requestId = uint32(1);
    uint32 _lockBlock = uint32(block.number);

    _mockStartRNGRequest(address(rng), address(0), 0, _requestId, _lockBlock);

    vm.expectEmit();
    emit RNGRequestStarted(_requestId, _lockBlock);

    rngRequestor.startRNGRequest(recipient);

    assertEq(rngRequestor.isRNGRequested(), true);
  }

  /* ============ isRNGCompleted ============ */
  function testIsRNGCompletedDefaultState() public {
    _mockIsRequestComplete(address(rng), uint32(0), false);
    assertEq(rngRequestor.isRNGCompleted(), false);
  }

  function testIsRNGCompletedActiveState() public {
    _mockIsRequestComplete(address(rng), uint32(0), true);
    assertEq(rngRequestor.isRNGCompleted(), true);
  }

  /* ============ isRNGTimedOut ============ */
  function testIsRNGTimedOutDefaultState() public {
    assertEq(rngRequestor.isRNGTimedOut(), false);
  }

  function testIsRNGTimedOutActiveState() public {
    uint32 _requestId = uint32(1);
    uint32 _lockBlock = uint32(block.number);

    _mockStartRNGRequest(address(rng), address(0), 0, _requestId, _lockBlock);

    rngRequestor.startRNGRequest(recipient);

    vm.warp(2 hours);
    assertEq(rngRequestor.isRNGTimedOut(), true);
  }

  /* ============ canStartRNGRequest ============ */
  function testCanStartRNGRequestDefaultState() public {
    assertEq(rngRequestor.canStartRNGRequest(), true);
  }

  function testCanStartRNGRequestActiveState() public {
    uint32 _requestId = uint32(1);
    uint32 _lockBlock = uint32(block.number);

    _mockStartRNGRequest(address(rng), address(0), 0, _requestId, _lockBlock);

    rngRequestor.startRNGRequest(recipient);

    assertEq(rngRequestor.canStartRNGRequest(), false);
  }

  /* ============ canCompleteRNGRequest ============ */
  function testCanCompleteRNGRequestDefaultState() public {
    assertEq(rngRequestor.canCompleteRNGRequest(), false);
  }

  function testCanCompleteRNGRequestActiveState() public {
    uint32 _requestId = uint32(1);
    uint32 _lockBlock = uint32(block.number);

    _mockStartRNGRequest(address(rng), address(0), 0, _requestId, _lockBlock);
    _mockIsRequestComplete(address(rng), _requestId, true);

    rngRequestor.startRNGRequest(recipient);

    assertEq(rngRequestor.canCompleteRNGRequest(), true);
  }

  /* ============ Getter Functions ============ */
  function testgetRNGLockBlock() public {
    assertEq(rngRequestor.getRNGLockBlock(), 0);
  }

  function testGetRNGRequestId() public {
    assertEq(rngRequestor.getRNGRequestId(), 0);
  }

  function testGetRNGTimeout() public {
    assertEq(rngRequestor.getRNGTimeout(), rngTimeOut);
  }

  function testGetRNGService() public {
    assertEq(address(rngRequestor.getRNGService()), address(rng));
  }

  /* ============ Setters ============ */

  /* ============ setRNGService ============ */
  function testSetRNGService() public {
    RNGInterface _newRNGService = RNGInterface(address(2));

    vm.expectEmit();
    emit RNGServiceSet(_newRNGService);

    rngRequestor.setRNGService(_newRNGService);

    assertEq(address(rngRequestor.getRNGService()), address(_newRNGService));
  }

  function testSetRNGServiceFail() public {
    vm.expectRevert(abi.encodeWithSelector(RNGRequestor.RNGNotZeroAddress.selector));

    rngRequestor.setRNGService(RNGInterface(address(0)));
  }

  /* ============ setRNGService ============ */
  function testSetRNGTimeout() public {
    uint32 _newRNGTimeout = 2 hours;

    vm.expectEmit();
    emit RNGTimeoutSet(_newRNGTimeout);

    rngRequestor.setRNGTimeout(_newRNGTimeout);

    assertEq(rngRequestor.getRNGTimeout(), _newRNGTimeout);
  }

  function testSetRNGTimeoutFail() public {
    uint32 _newRNGTimeout = 0;

    vm.expectRevert(
      abi.encodeWithSelector(RNGRequestor.RNGTimeoutLT60Seconds.selector, _newRNGTimeout)
    );

    rngRequestor.setRNGTimeout(_newRNGTimeout);
  }
}
