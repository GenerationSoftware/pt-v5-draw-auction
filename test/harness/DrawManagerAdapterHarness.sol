// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { DrawManagerAdapter } from "local-draw-auction/erc5164/DrawManagerAdapter.sol";
import { ISingleMessageDispatcher } from "local-draw-auction/interfaces/ISingleMessageDispatcher.sol";

contract DrawManagerAdapterHarness is DrawManagerAdapter {
  constructor(
    ISingleMessageDispatcher dispatcher_,
    address drawManagerReceiver_,
    uint256 toChainId_,
    address admin_,
    address drawCloser_
  ) DrawManagerAdapter(dispatcher_, drawManagerReceiver_, toChainId_, admin_, drawCloser_) {}

  /**
   * @notice Set the dispatcher.
   * @param dispatcher_ Address of the dispatcher
   */
  function setDispatcher(ISingleMessageDispatcher dispatcher_) external {
    _setDispatcher(dispatcher_);
  }

  /**
   * @notice Set the drawManagerReceiver.
   * @param drawManagerReceiver_ Address of the drawManagerReceiver
   */
  function setDrawManagerReceiver(address drawManagerReceiver_) external {
    _setDrawManagerReceiver(drawManagerReceiver_);
  }
}
