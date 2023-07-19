// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import { PrizePool, TieredLiquidityDistributor } from "v5-prize-pool/PrizePool.sol";
import { RNGInterface } from "rng/RNGInterface.sol";
import { UD2x18 } from "prb-math/UD2x18.sol";

import { Phase, PhaseManager } from "local-draw-auction/abstract/PhaseManager.sol";
import { RngAuction } from "local-draw-auction/RngAuction.sol";

contract Helpers is Test {
  /* ============ RngAuction ============ */

  function _mockRngAuction_getResults(
    RngAuction _rngAuction,
    RngAuction.RngRequest memory _rngRequest,
    uint64 _rngCompletedAt
  ) internal {
    vm.mockCall(
      address(_rngAuction),
      abi.encodeWithSelector(RngAuction.getResults.selector),
      abi.encode(_rngRequest, _rngCompletedAt)
    );
  }

  function _mockRngAuction_randomNumber(RngAuction _rngAuction, uint256 _randomNumber) internal {
    vm.mockCall(
      address(_rngAuction),
      abi.encodeWithSelector(RngAuction.randomNumber.selector),
      abi.encode(_randomNumber)
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

  /* ============ PhaseManager ============ */

  function _mockPhaseManager_getPhase(PhaseManager _phaseManager, Phase memory _phase) internal {
    vm.mockCall(
      address(_phaseManager),
      abi.encodeWithSelector(PhaseManager.getPhase.selector),
      abi.encode(_phase)
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
