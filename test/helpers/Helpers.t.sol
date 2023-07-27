// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import { PrizePool, TieredLiquidityDistributor } from "pt-v5-prize-pool/PrizePool.sol";
import { RNGInterface } from "rng/RNGInterface.sol";
import { UD2x18 } from "prb-math/UD2x18.sol";

import { IAuction, AuctionResults } from "local-draw-auction/interfaces/IAuction.sol";
import { IDrawManager } from "local-draw-auction/interfaces/IDrawManager.sol";
import { StartRngAuction } from "local-draw-auction/StartRngAuction.sol";

contract Helpers is Test {
  /* ============ StartRngAuction ============ */

  function _mockStartRngAuction_getRngResults(
    StartRngAuction _rngAuction,
    StartRngAuction.RngRequest memory _rngRequest,
    uint256 _randomNumber,
    uint64 _rngCompletedAt
  ) internal {
    vm.mockCall(
      address(_rngAuction),
      abi.encodeWithSelector(StartRngAuction.getRngResults.selector),
      abi.encode(_rngRequest, _randomNumber, _rngCompletedAt)
    );
  }

  function _mockStartRngAuction_isRngComplete(StartRngAuction _rngAuction, bool _isCompleted) internal {
    vm.mockCall(
      address(_rngAuction),
      abi.encodeWithSelector(StartRngAuction.isRngComplete.selector),
      abi.encode(_isCompleted)
    );
  }

  function _mockStartRngAuction_getRngService(StartRngAuction _rngAuction, RNGInterface _rng) internal {
    vm.mockCall(
      address(_rngAuction),
      abi.encodeWithSelector(StartRngAuction.getRngService.selector),
      abi.encode(_rng)
    );
  }

  function _mockStartRngAuction_currentSequenceId(
    StartRngAuction _rngAuction,
    uint32 _currentSequenceId
  ) internal {
    vm.mockCall(
      address(_rngAuction),
      abi.encodeWithSelector(StartRngAuction.currentSequenceId.selector),
      abi.encode(_currentSequenceId)
    );
  }

  function _mockStartRngAuction_rngCompletedAt(StartRngAuction _rngAuction, uint64 _rngCompletedAt) internal {
    vm.mockCall(
      address(_rngAuction),
      abi.encodeWithSelector(StartRngAuction.rngCompletedAt.selector),
      abi.encode(_rngCompletedAt)
    );
  }

  /* ============ IAuction ============ */

  function _mockIAuction_getAuctionResults(
    IAuction _auction,
    AuctionResults memory _auctionResults,
    uint32 _sequenceId
  ) internal {
    vm.mockCall(
      address(_auction),
      abi.encodeWithSelector(IAuction.getAuctionResults.selector),
      abi.encode(_auctionResults, _sequenceId)
    );
  }

  /* ============ RNGInterface ============ */

  function _mockRngInterface_startRngRequest(
    RNGInterface _rng,
    address _feeToken,
    uint256 _requestFee,
    uint32 _requestId,
    uint32 _lockBlock
  ) internal {
    _mockRngInterface_getRequestFee(_rng, _feeToken, _requestFee);
    _mockRngInterface_requestRandomNumber(_rng, _requestId, _lockBlock);
  }

  function _mockRngInterface_completedAt(
    RNGInterface _rng,
    uint32 _requestId,
    uint64 _completedAt
  ) internal {
    vm.mockCall(
      address(_rng),
      abi.encodeWithSelector(RNGInterface.completedAt.selector, _requestId),
      abi.encode(_completedAt)
    );
  }

  function _mockRngInterface_randomNumber(
    RNGInterface _rng,
    uint32 _requestId,
    uint256 _randomNumber
  ) internal {
    vm.mockCall(
      address(_rng),
      abi.encodeWithSelector(RNGInterface.randomNumber.selector, _requestId),
      abi.encode(_randomNumber)
    );
  }

  function _mockRngInterface_getRequestFee(
    RNGInterface _rng,
    address _feeToken,
    uint256 _requestFee
  ) internal {
    vm.mockCall(
      address(_rng),
      abi.encodeWithSelector(RNGInterface.getRequestFee.selector),
      abi.encode(_feeToken, _requestFee)
    );
  }

  function _mockRngInterface_requestRandomNumber(
    RNGInterface _rng,
    uint32 _requestId,
    uint32 _lockBlock
  ) internal {
    vm.mockCall(
      address(_rng),
      abi.encodeWithSelector(RNGInterface.requestRandomNumber.selector),
      abi.encode(_requestId, _lockBlock)
    );
  }

  function _mockRngInterface_isRequestComplete(
    RNGInterface _rng,
    uint32 _requestId,
    bool _isRequestComplete
  ) internal {
    vm.mockCall(
      address(_rng),
      abi.encodeWithSelector(RNGInterface.isRequestComplete.selector, _requestId),
      abi.encode(_isRequestComplete)
    );
  }
}
