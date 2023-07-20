// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ExecutorAware } from "local-draw-auction/abstract/ExecutorAware.sol";
import { AuctionResults } from "local-draw-auction/interfaces/IAuction.sol";
import { IDrawManager } from "local-draw-auction/interfaces/IDrawManager.sol";

contract DrawManagerReceiver is IDrawManager, ExecutorAware {
  /* ============ Events ============ */

  /**
   * @notice Emitted when the DrawManagerAdapter has been set.
   * @param drawManagerAdapter Address of the DrawManagerAdapter
   */
  event DrawManagerAdapterSet(address drawManagerAdapter);

  /* ============ Custom Errors ============ */

  /// @notice Thrown when the originChainId passed to the constructor is zero.
  error OriginChainIdZero();

  /// @notice Thrown when the DrawManagerAdapter address passed to the constructor is zero address.
  error DrawManagerAdapterZeroAddress();

  /// @notice Thrown if the DrawManagerAdapter has already been set.
  error DrawManagerAdapterAlreadySet();

  /// @notice Thrown when the DrawManager address passed to the constructor is the zero address.
  error DrawManagerZeroAddress();

  /// @notice Thrown when the message was dispatched from an unsupported chain ID.
  error L1ChainIdUnsupported(uint256 fromChainId);

  /// @notice Thrown when the message was not executed by the executor.
  error L2SenderNotExecutor(address sender);

  /// @notice Thrown when the message was not dispatched by the DrawManagerAdapter on the origin chain.
  error L1SenderNotAdapter(address sender);

  /* ============ Variables ============ */

  /// @notice ID of the origin chain that dispatches the auction auction results and random number.
  uint256 internal immutable _originChainId;

  /// @notice Address of the DrawManagerAdapter on the origin chain that dispatches the auction auction results and random number.
  address internal _drawManagerAdapter;

  /// @notice Address of the DrawManager on L2 to complete
  IDrawManager internal immutable _drawManager;

  /* ============ Constructor ============ */

  /**
   * @notice DrawManagerReceiver constructor.
   * @param originChainId_ ID of the origin chain
   * @param executor_ Address of the ERC-5164 contract that executes the bridged calls
   * @param drawManager_ Address of the Draw Manager to call with auction data
   */
  constructor(
    uint256 originChainId_,
    address executor_,
    IDrawManager drawManager_
  ) ExecutorAware(executor_) {
    if (originChainId_ == 0) revert OriginChainIdZero();
    if (address(drawManager_) == address(0)) revert DrawManagerZeroAddress();

    _originChainId = originChainId_;
    _drawManager = drawManager_;
  }

  /* ============ External Functions ============ */

  /**
   * @inheritdoc IDrawManager
   * @dev Calls the DrawManager to close the draw.
   */
  function closeDraw(uint256 _randomNumber, AuctionResults[] memory _auctionResults) external {
    _checkSender();
    _drawManager.closeDraw(_randomNumber, _auctionResults);
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
   * @notice Get the address of the DrawManagerAdapter on the origin chain.
   * @return Address of the DrawManagerAdapter on the origin chain
   */
  function drawManagerAdapter() external view returns (address) {
    return _drawManagerAdapter;
  }

  /**
   * @notice Get the address of the DrawManager that this executor calls
   * @return DrawManager that this executor will call
   */
  function drawManager() external view returns (IDrawManager) {
    return _drawManager;
  }

  /* ============ Setters ============ */

  /**
   * @notice Set the DrawManagerAdapter address.
   * @dev Can only be called once.
   *      If the transaction get front-run at deployment, we can always re-deploy the contract.
   */
  function setDrawManagerAdapter(address drawManagerAdapter_) external {
    if (_drawManagerAdapter != address(0)) revert DrawManagerAdapterAlreadySet();
    if (drawManagerAdapter_ == address(0)) revert DrawManagerAdapterZeroAddress();

    _drawManagerAdapter = drawManagerAdapter_;

    emit DrawManagerAdapterSet(drawManagerAdapter_);
  }

  /* ============ Internal Functions ============ */

  /**
   * @notice Checks that:
   *          - the call has been dispatched from the supported chain
   *          - the sender on the receiving chain is the executor
   *          - the sender on the origin chain is the DrawMangerAdapter
   */
  function _checkSender() internal view {
    if (_fromChainId() != _originChainId) revert L1ChainIdUnsupported(_fromChainId());
    if (!isTrustedExecutor(msg.sender)) revert L2SenderNotExecutor(msg.sender);
    if (_msgSender() != address(_drawManagerAdapter)) revert L1SenderNotAdapter(_msgSender());
  }
}
