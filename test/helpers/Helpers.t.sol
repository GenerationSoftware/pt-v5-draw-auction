// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import { PrizePool, TieredLiquidityDistributor } from "v5-prize-pool/PrizePool.sol";
import { RNGInterface } from "rng/RNGInterface.sol";

import { AuctionLib } from "../../src/libraries/AuctionLib.sol";

contract Helpers is Test {
  /* ============ Mock Functions ============ */

  /* ============ RNGRequestor ============ */
  function _mockGetRequestFee(address _rng, address _feeToken, uint256 _requestFee) internal {
    vm.mockCall(
      _rng,
      abi.encodeWithSelector(RNGInterface.getRequestFee.selector),
      abi.encode(_feeToken, _requestFee)
    );
  }

  function _mockRequestRandomNumber(address _rng, uint32 _requestId, uint32 _lockBlock) internal {
    vm.mockCall(
      _rng,
      abi.encodeWithSelector(RNGInterface.requestRandomNumber.selector),
      abi.encode(_requestId, _lockBlock)
    );
  }

  function _mockStartRNGRequest(
    address _rng,
    address _feeToken,
    uint256 _requestFee,
    uint32 _requestId,
    uint32 _lockBlock
  ) internal {
    _mockGetRequestFee(_rng, _feeToken, _requestFee);
    _mockRequestRandomNumber(_rng, _requestId, _lockBlock);
  }

  function _mockIsRequestComplete(
    address _rng,
    uint32 _requestId,
    bool _isRequestComplete
  ) internal {
    vm.mockCall(
      _rng,
      abi.encodeWithSelector(RNGInterface.isRequestComplete.selector, _requestId),
      abi.encode(_isRequestComplete)
    );
  }

  function _mockRandomNumber(address _rng, uint32 _requestId, uint256 _randomNumber) internal {
    vm.mockCall(
      _rng,
      abi.encodeWithSelector(RNGInterface.randomNumber.selector, _requestId),
      abi.encode(_randomNumber)
    );
  }

  function _mockCompleteRNGRequest(
    address _rng,
    uint32 _requestId,
    uint256 _randomNumber
  ) internal {
    _mockIsRequestComplete(_rng, _requestId, true);
    _mockRandomNumber(_rng, _requestId, _randomNumber);
  }

  /* ============ PrizePool ============ */
  function _mockReserve(address _prizePool, uint256 _amount) internal {
    vm.mockCall(
      _prizePool,
      abi.encodeWithSelector(TieredLiquidityDistributor.reserve.selector),
      abi.encode(_amount)
    );
  }

  function _mockReserveForOpenDraw(address _prizePool, uint256 _amount) internal {
    vm.mockCall(
      _prizePool,
      abi.encodeWithSelector(PrizePool.reserveForOpenDraw.selector),
      abi.encode(_amount)
    );
  }

  function _mockReserves(address _prizePool, uint256 _reserveAmount) internal {
    uint256 _amount = _reserveAmount / 2;

    _mockReserve(_prizePool, _amount);
    _mockReserveForOpenDraw(_prizePool, _amount);
  }

  /* ============ Computations ============ */

  function _computeReward(
    uint64 _elapsedTime,
    uint256 _reserve,
    uint32 _auctionDuration
  ) internal pure returns (uint256) {
    return (_elapsedTime * _reserve) / _auctionDuration;
  }

  /* ============ Getters ============ */

  function _getPhase(
    uint8 _phaseId,
    uint64 _startTime,
    uint64 _endTime,
    address _recipient
  ) internal pure returns (AuctionLib.Phase memory) {
    return
      AuctionLib.Phase({
        id: _phaseId,
        startTime: _startTime,
        endTime: _endTime,
        recipient: _recipient
      });
  }
}
