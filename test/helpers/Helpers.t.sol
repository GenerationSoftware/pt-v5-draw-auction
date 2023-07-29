// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import { PrizePool, TieredLiquidityDistributor } from "pt-v5-prize-pool/PrizePool.sol";
import { RNGInterface } from "rng/RNGInterface.sol";
import { UD2x18 } from "prb-math/UD2x18.sol";

import { IAuction } from "../../src/interfaces/IAuction.sol";
import { RngAuction } from "../../src/RngAuction.sol";

contract Helpers is Test {
  /* ============ RngAuction ============ */

  function _mockRngAuction_isRngComplete(RngAuction _rngAuction, bool _isCompleted) internal {
    vm.mockCall(
      address(_rngAuction),
      abi.encodeWithSelector(RngAuction.isRngComplete.selector),
      abi.encode(_isCompleted)
    );
  }

  function _mockRngAuction_openSequenceId(
    RngAuction _rngAuction,
    uint32 _openSequenceId
  ) internal {
    vm.mockCall(
      address(_rngAuction),
      abi.encodeWithSelector(RngAuction.openSequenceId.selector),
      abi.encode(_openSequenceId)
    );
  }

  /* ============ IAuction ============ */

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
