// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

import { ERC20Mock } from "openzeppelin/mocks/ERC20Mock.sol";
import { RNGInterface } from "rng/RNGInterface.sol";

import { RNGRequestor } from "src/RNGRequestor.sol";

contract RNGRequestorTest is Test {
  /* ============ Events ============ */

  event RNGServiceSet(RNGInterface indexed rngService);
  event RNGTimeoutSet(uint32 rngTimeout);
  event RNGRequestStarted(uint32 indexed rngRequestId, uint32 rngLockBlock);
  event RNGRequestCompleted(uint32 indexed rngRequestId, uint256 randomNumber);
  event RNGRequestCancelled(uint32 indexed rngRequestId, uint32 rngLockBlock);

  /* ============ Variables ============ */

  RNGInterface public rng;
  RNGRequestor public rngRequestor;
  uint32 public rngTimeOut;

  ERC20Mock public feeToken;
  uint256 public feeAmount;

  function setUp() public {
    feeToken = new ERC20Mock();
    feeAmount = 2e18;

    rng = RNGInterface(address(1));
    rngTimeOut = 1 hours;

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

    _mockGetRequestFee(address(0), 0);
    _mockRequestRandomNumber(_requestId, _lockBlock);

    vm.expectEmit();
    emit RNGRequestStarted(_requestId, _lockBlock);

    rngRequestor.startRNGRequest();

    assertEq(rngRequestor.getRNGLockBlock(), _lockBlock);
    assertEq(rngRequestor.getRNGRequestId(), _requestId);
  }

  // @TODO Test with ChainlinkVRFV2 direct LINK transfer contact
  function testStartRNGRequestWithFeeToken() public {
    uint32 _requestId = uint32(1);
    uint32 _lockBlock = uint32(block.number);

    _mockGetRequestFee(address(feeToken), feeAmount);
    _mockRequestRandomNumber(_requestId, _lockBlock);

    vm.expectEmit();
    emit RNGRequestStarted(_requestId, _lockBlock);

    rngRequestor.startRNGRequest();

    assertEq(rngRequestor.getRNGLockBlock(), _lockBlock);
    assertEq(rngRequestor.getRNGRequestId(), _requestId);
  }

  function testStartRNGRequestFailRNGRequested() public {
    uint32 _requestId = uint32(1);
    uint32 _lockBlock = uint32(block.number);

    _mockGetRequestFee(address(0), 0);
    _mockRequestRandomNumber(_requestId, _lockBlock);

    rngRequestor.startRNGRequest();

    vm.expectRevert(abi.encodeWithSelector(RNGRequestor.RNGRequested.selector, _requestId));

    rngRequestor.startRNGRequest();
  }

  /* ============ completeRNGRequest ============ */
  function testCompleteRNGRequest() public {
    uint32 _requestId = uint32(1);
    uint32 _lockBlock = uint32(block.number);
    uint256 _randomNumber = 123456789;

    _mockGetRequestFee(address(0), 0);
    _mockRequestRandomNumber(_requestId, _lockBlock);

    rngRequestor.startRNGRequest();

    _mockIsRequestComplete(_requestId, true);
    _mockRandomNumber(_requestId, _randomNumber);

    vm.expectEmit();
    emit RNGRequestCompleted(_requestId, _randomNumber);

    rngRequestor.completeRNGRequest();
  }

  function testCompleteRNGRequestFailRNGNotRequested() public {
    vm.expectRevert(abi.encodeWithSelector(RNGRequestor.RNGNotRequested.selector));

    rngRequestor.completeRNGRequest();
  }

  function testCompleteRNGRequestFailRNGNotCompleted() public {
    uint32 _requestId = uint32(1);
    uint32 _lockBlock = uint32(block.number);

    _mockGetRequestFee(address(0), 0);
    _mockRequestRandomNumber(_requestId, _lockBlock);

    rngRequestor.startRNGRequest();

    _mockIsRequestComplete(_requestId, false);

    vm.expectRevert(abi.encodeWithSelector(RNGRequestor.RNGNotCompleted.selector, _requestId));

    rngRequestor.completeRNGRequest();
  }

  /* ============ cancelRNGRequest ============ */
  function testCancelRNGRequest() public {
    uint32 _requestId = uint32(1);
    uint32 _lockBlock = uint32(block.number);

    _mockGetRequestFee(address(0), 0);
    _mockRequestRandomNumber(_requestId, _lockBlock);

    rngRequestor.startRNGRequest();

    vm.warp(2 hours);

    vm.expectEmit();
    emit RNGRequestCancelled(_requestId, _lockBlock);

    rngRequestor.cancelRNGRequest();
  }

  function testCancelRNGRequestFail() public {
    uint32 _requestId = uint32(1);
    uint32 _lockBlock = uint32(block.number);

    _mockGetRequestFee(address(0), 0);
    _mockRequestRandomNumber(_requestId, _lockBlock);

    rngRequestor.startRNGRequest();

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

    _mockGetRequestFee(address(0), 0);
    _mockRequestRandomNumber(_requestId, _lockBlock);

    vm.expectEmit();
    emit RNGRequestStarted(_requestId, _lockBlock);

    rngRequestor.startRNGRequest();

    assertEq(rngRequestor.isRNGRequested(), true);
  }

  /* ============ isRNGCompleted ============ */
  function testIsRNGCompletedDefaultState() public {
    _mockIsRequestComplete(uint32(0), false);
    assertEq(rngRequestor.isRNGCompleted(), false);
  }

  function testIsRNGCompletedActiveState() public {
    _mockIsRequestComplete(uint32(0), true);
    assertEq(rngRequestor.isRNGCompleted(), true);
  }

  /* ============ isRNGTimedOut ============ */
  function testIsRNGTimedOutDefaultState() public {
    assertEq(rngRequestor.isRNGTimedOut(), false);
  }

  function testIsRNGTimedOutActiveState() public {
    uint32 _requestId = uint32(1);
    uint32 _lockBlock = uint32(block.number);

    _mockGetRequestFee(address(0), 0);
    _mockRequestRandomNumber(_requestId, _lockBlock);

    rngRequestor.startRNGRequest();

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

    _mockGetRequestFee(address(0), 0);
    _mockRequestRandomNumber(_requestId, _lockBlock);

    rngRequestor.startRNGRequest();

    assertEq(rngRequestor.canStartRNGRequest(), false);
  }

  /* ============ canCompleteRNGRequest ============ */
  function testCanCompleteRNGRequestDefaultState() public {
    assertEq(rngRequestor.canCompleteRNGRequest(), false);
  }

  function testCanCompleteRNGRequestActiveState() public {
    uint32 _requestId = uint32(1);
    uint32 _lockBlock = uint32(block.number);

    _mockGetRequestFee(address(0), 0);
    _mockRequestRandomNumber(_requestId, _lockBlock);
    _mockIsRequestComplete(_requestId, true);

    rngRequestor.startRNGRequest();

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

  /* ============ Setter Functions ============ */

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

  /* ============ Mock Functions ============ */
  function _mockGetRequestFee(address _feeToken, uint256 _requestFee) internal {
    vm.mockCall(
      address(rng),
      abi.encodeWithSelector(RNGInterface.getRequestFee.selector),
      abi.encode(_feeToken, _requestFee)
    );
  }

  function _mockRequestRandomNumber(uint32 _requestId, uint32 _lockBlock) internal {
    vm.mockCall(
      address(rng),
      abi.encodeWithSelector(RNGInterface.requestRandomNumber.selector),
      abi.encode(_requestId, _lockBlock)
    );
  }

  function _mockRandomNumber(uint32 _requestId, uint256 _randomNumber) internal {
    vm.mockCall(
      address(rng),
      abi.encodeWithSelector(RNGInterface.randomNumber.selector, _requestId),
      abi.encode(_randomNumber)
    );
  }

  function _mockIsRequestComplete(uint32 _requestId, bool _isRequestComplete) internal {
    vm.mockCall(
      address(rng),
      abi.encodeWithSelector(RNGInterface.isRequestComplete.selector, _requestId),
      abi.encode(_isRequestComplete)
    );
  }
}
