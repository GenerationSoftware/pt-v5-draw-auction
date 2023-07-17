// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import { PrizePool, TieredLiquidityDistributor } from "v5-prize-pool/PrizePool.sol";
import { RNGInterface } from "rng/RNGInterface.sol";
import { UD2x18 } from "prb-math/UD2x18.sol";

import { Phase, PhaseManager } from "local-draw-auction/abstract/PhaseManager.sol";
import { RNGAuction } from "local-draw-auction/RNGAuction.sol";

contract Helpers is Test {
  /* ============ RNGAuction ============ */

  function _mockRNGAuction_getRNGRequestId(RNGAuction _rngAuction, uint32 _requestId) internal {
    vm.mockCall(
      address(_rngAuction),
      abi.encodeWithSelector(RNGAuction.getRNGRequestId.selector),
      abi.encode(_requestId)
    );
  }

  function _mockRNGAuction_isRNGCompleted(RNGAuction _rngAuction, bool _isCompleted) internal {
    vm.mockCall(
      address(_rngAuction),
      abi.encodeWithSelector(RNGAuction.isRNGCompleted.selector),
      abi.encode(_isCompleted)
    );
  }

  function _mockRNGAuction_getRNGService(RNGAuction _rngAuction, RNGInterface _rng) internal {
    vm.mockCall(
      address(_rngAuction),
      abi.encodeWithSelector(RNGAuction.getRNGService.selector),
      abi.encode(_rng)
    );
  }

  /* ============ PhaseManager ============ */

  function _mockPhaseManager_getPhase(
    PhaseManager _phaseManager,
    uint256 _phaseId,
    Phase memory _phase
  ) internal {
    vm.mockCall(
      address(_phaseManager),
      abi.encodeWithSelector(PhaseManager.getPhase.selector, _phaseId),
      abi.encode(_phase)
    );
  }

  /* ============ RNGInterface ============ */

  function _mockRNGInterface_completedAt(
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

  function _mockRNGInterface_randomNumber(
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
