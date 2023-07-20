// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import { PrizePool, TieredLiquidityDistributor } from "v5-prize-pool/PrizePool.sol";
import { RNGInterface } from "rng/RNGInterface.sol";
import { UD2x18 } from "prb-math/UD2x18.sol";

import { IAuction, AuctionResults } from "local-draw-auction/interfaces/IAuction.sol";
import { RngAuction } from "local-draw-auction/RngAuction.sol";

contract Helpers is Test {
  /* ============ RngAuction ============ */

  function _mockRngAuction_getRngResults(
    RngAuction _rngAuction,
    RngAuction.RngRequest memory _rngRequest,
    uint256 _randomNumber,
    uint64 _rngCompletedAt
  ) internal {
    vm.mockCall(
      address(_rngAuction),
      abi.encodeWithSelector(RngAuction.getRngResults.selector),
      abi.encode(_rngRequest, _randomNumber, _rngCompletedAt)
    );
  }

  function _mockRngAuction_isRngComplete(RngAuction _rngAuction, bool _isCompleted) internal {
    vm.mockCall(
      address(_rngAuction),
      abi.encodeWithSelector(RngAuction.isRngComplete.selector),
      abi.encode(_isCompleted)
    );
  }

  function _mockRngAuction_getRngService(RngAuction _rngAuction, RNGInterface _rng) internal {
    vm.mockCall(
      address(_rngAuction),
      abi.encodeWithSelector(RngAuction.getRngService.selector),
      abi.encode(_rng)
    );
  }

  function _mockRngAuction_currentSequenceId(
    RngAuction _rngAuction,
    uint32 _currentSequenceId
  ) internal {
    vm.mockCall(
      address(_rngAuction),
      abi.encodeWithSelector(RngAuction.currentSequenceId.selector),
      abi.encode(_currentSequenceId)
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
}
