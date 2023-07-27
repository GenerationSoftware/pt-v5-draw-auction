// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import { ISingleMessageDispatcher } from "local-draw-auction/interfaces/ISingleMessageDispatcher.sol";

contract MockDispatcher is ISingleMessageDispatcher {
  event MockMessageDispatched(uint256 toChainId, address to, bytes data);

  function dispatchMessage(
    uint256 toChainId,
    address to,
    bytes calldata data
  ) external returns (bytes32) {
    emit MockMessageDispatched(toChainId, to, data);
    return bytes32(0);
  }
}
