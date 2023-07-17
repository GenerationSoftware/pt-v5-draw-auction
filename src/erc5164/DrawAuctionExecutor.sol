// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ExecutorAware } from "local-draw-auction/abstract/ExecutorAware.sol";
import { Phase } from "local-draw-auction/abstract/PhaseManager.sol";
import { DrawManager } from "local-draw-auction/DrawManager.sol";

contract DrawAuctionExecutor is ExecutorAware {
  /* ============ Events ============ */

  /**
   * @notice Emitted when the DrawAuctionDispatcher has been set.
   * @param drawAuctionDispatcher Address of the DrawAuctionDispatcher
   */
  event DrawAuctionDispatcherSet(address drawAuctionDispatcher);

  /* ============ Custom Errors ============ */

  /// @notice Thrown when the originChainId passed to the constructor is zero.
  error OriginChainIdZero();

  /// @notice Thrown when the DrawAuctionDispatcher address passed to the constructor is zero address.
  error DrawAuctionDispatcherZeroAddress();

  /// @notice Thrown if the DrawAuctionDispatcher has already been set.
  error DrawAuctionDispatcherAlreadySet();

  /// @notice Thrown when the DrawManager address passed to the constructor is the zero address.
  error DrawManagerZeroAddress();

  /// @notice Thrown when the message was dispatched from an unsupported chain ID.
  error L1ChainIdUnsupported(uint256 fromChainId);

  /// @notice Thrown when the message was not executed by the executor.
  error L2SenderNotExecutor(address sender);

  /// @notice Thrown when the message was not dispatched by the DrawAuctionDispatcher on the origin chain.
  error L1SenderNotDispatcher(address sender);

  /* ============ Variables ============ */

  /// @notice ID of the origin chain that dispatches the auction phases and random number.
  uint256 internal immutable _originChainId;

  /// @notice Address of the DrawAuctionDispatcher on the origin chain that dispatches the auction phases and random number.
  address internal _drawAuctionDispatcher;

  /// @notice Address of the DrawManager on L2 to complete
  DrawManager internal immutable _drawManager;

  /* ============ Constructor ============ */

  /**
   * @notice DrawAuctionExecutor constructor.
   * @param originChainId_ ID of the origin chain
   * @param executor_ Address of the ERC-5164 contract that executes the bridged calls
   * @param drawManager_ Address of the Draw Manager to call with auction data
   */
  constructor(
    uint256 originChainId_,
    address executor_,
    DrawManager drawManager_
  ) ExecutorAware(executor_) {
    if (originChainId_ == 0) revert OriginChainIdZero();
    if (address(drawManager_) == address(0)) revert DrawManagerZeroAddress();

    _originChainId = originChainId_;
    _drawManager = drawManager_;
  }

  /* ============ External Functions ============ */

  /**
   * @notice Complete the auction and current draw.
   * @param _randomNumber Random number generated by the RNG service on the origin chain
   * @param _auctionPhases Array of auction phases
   */
  function completeAuction(uint256 _randomNumber, Phase[] memory _auctionPhases) external {
    _checkSender();
    _drawManager.closeDraw(_randomNumber, _auctionPhases);
  }

  /* ============ Getter Functions ============ */

  /**
   * @notice Get the ID of the origin chain.
   * @return ID of the origin chain
   */
  function originChainId() external view returns (uint256) {
    return _originChainId;
  }

  /**
   * @notice Get the address of the DrawAuctionDispatcher on the origin chain.
   * @return Address of the DrawAuctionDispatcher on the origin chain
   */
  function drawAuctionDispatcher() external view returns (address) {
    return _drawAuctionDispatcher;
  }

  /**
   * @notice Get the address of the DrawManager that this executor calls
   * @return DrawManager that this executor will call
   */
  function drawManager() external view returns (DrawManager) {
    return _drawManager;
  }

  /* ============ Setters ============ */

  /**
   * @notice Set the DrawAuctionDispatcher address.
   * @dev Can only be called once.
   *      If the transaction get front-run at deployment, we can always re-deploy the contract.
   */
  function setDrawAuctionDispatcher(address drawAuctionDispatcher_) external {
    if (_drawAuctionDispatcher != address(0)) revert DrawAuctionDispatcherAlreadySet();
    if (drawAuctionDispatcher_ == address(0)) revert DrawAuctionDispatcherZeroAddress();

    _drawAuctionDispatcher = drawAuctionDispatcher_;

    emit DrawAuctionDispatcherSet(drawAuctionDispatcher_);
  }

  /* ============ Internal Functions ============ */

  /**
   * @notice Checks that:
   *          - the call has been dispatched from the supported chain
   *          - the sender on the receiving chain is the executor
   *          - the sender on the origin chain is the DrawDispatcher
   */
  function _checkSender() internal view {
    if (_fromChainId() != _originChainId) revert L1ChainIdUnsupported(_fromChainId());
    if (!isTrustedExecutor(msg.sender)) revert L2SenderNotExecutor(msg.sender);
    if (_msgSender() != address(_drawAuctionDispatcher)) revert L1SenderNotDispatcher(_msgSender());
  }
}
