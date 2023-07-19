// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { AccessControl } from "openzeppelin/access/AccessControl.sol";

import { IDrawManager } from "local-draw-auction/interfaces/IDrawManager.sol";
import { Phase } from "local-draw-auction/abstract/PhaseManager.sol";
import { ISingleMessageDispatcher } from "local-draw-auction/interfaces/ISingleMessageDispatcher.sol";

/**
 * @title PoolTogether V5 DrawManagerAdapter
 * @author Generation Software Team
 * @notice The DrawManagerAdapter acts as a proxy to send messages through a DrawManager on a receiving chain.
 */
contract DrawManagerAdapter is IDrawManager, AccessControl {
  /* ============ Events ============ */

  /**
   * @notice Event emitted when the random number and auction phases have been dispatched.
   * @param dispatcher Instance of the dispatcher on Ethereum that dispatched the phases and random number
   * @param toChainId ID of the receiving chain
   * @param drawManagerReceiver Address of the DrawManagerReceiver on the receiving chain that will award the auctions and complete the Draw
   * @param randomNumber Random number computed by the RNG
   * @param phases Array of auction phases
   */
  event MessageDispatched(
    ISingleMessageDispatcher indexed dispatcher,
    uint256 indexed toChainId,
    address indexed drawManagerReceiver,
    uint256 randomNumber,
    Phase[] phases
  );

  /* ============ Custom Errors ============ */

  /// @notice Thrown when the Dispatcher address passed to the constructor is zero address.
  error DispatcherZeroAddress();

  /// @notice Thrown when the toChainId passed to the constructor is zero.
  error ToChainIdZero();

  /// @notice Thrown when the DrawManagerReceiver address passed to the constructor is zero address.
  error DrawManagerReceiverZeroAddress();

  /* ============ Constants ============ */

  bytes32 public constant DRAW_CLOSER_ROLE = bytes32(uint256(0x01));

  /// @notice ID of the receiving chain
  uint256 internal immutable _toChainId;

  /* ============ Variables ============ */

  /// @notice Instance of the dispatcher on Ethereum
  ISingleMessageDispatcher internal _dispatcher;

  /// @notice Address of the DrawManagerReceiver that will close the draw on the destination chain.
  address internal _drawManagerReceiver;

  /* ============ Constructor ============ */

  /**
   * @notice Contract constructor.
   * @param dispatcher_ Instance of the dispatcher on Ethereum that will dispatch the phases and random number
   * @param drawManagerReceiver_ Address of the DrawManagerReceiver on the destination chain
   * @param toChainId_ ID of the receiving chain
   * @param admin_ The admin of the contract
   * @param drawCloser_ The address that will receive the draw closer role
   */
  constructor(
    ISingleMessageDispatcher dispatcher_,
    address drawManagerReceiver_,
    uint256 toChainId_,
    address admin_,
    address drawCloser_
  ) AccessControl() {
    _setDispatcher(dispatcher_);
    _setDrawManagerReceiver(drawManagerReceiver_);
    _grantRole(DEFAULT_ADMIN_ROLE, admin_);
    _grantRole(DRAW_CLOSER_ROLE, drawCloser_);

    if (toChainId_ == 0) revert ToChainIdZero();
    _toChainId = toChainId_;
  }

  /* ============ External Functions ============ */

  /* ============ Getters ============ */

  /**
   * @notice Get the dispatcher.
   * @return Instance of the dispatcher
   */
  function dispatcher() external view returns (ISingleMessageDispatcher) {
    return _dispatcher;
  }

  /**
   * @notice Get the drawManagerReceiver address on the receiving chain.
   * @return Address of the DrawManagerReceiver on the receiving chain
   */
  function drawManagerReceiver() external view returns (address) {
    return _drawManagerReceiver;
  }

  /**
   * @notice Get the toChainId.
   * @return ID of the receiving chain
   */
  function toChainId() external view returns (uint256) {
    return _toChainId;
  }

  /* ============ IDrawManager Implementation ============ */

  /**
   * @inheritdoc IDrawManager
   * @dev Completes the draw by dispatching the completed phases and random number through the dispatcher.
   * @dev Requires that sender is manager
   */
  function closeDraw(
    uint256 _randomNumber,
    Phase[] memory _auctionPhases
  ) external onlyRole(DRAW_CLOSER_ROLE) {
    _dispatcher.dispatchMessage(
      _toChainId,
      _drawManagerReceiver,
      abi.encodeWithSignature(
        "closeDraw(uint256,(uint64,address)[])",
        _randomNumber,
        _auctionPhases
      )
    );

    emit MessageDispatched(
      _dispatcher,
      _toChainId,
      _drawManagerReceiver,
      _randomNumber,
      _auctionPhases
    );
  }

  /* ============ Internal Functions ============ */

  /* ============ Setters ============ */

  /**
   * @notice Set the dispatcher.
   * @param dispatcher_ Address of the dispatcher
   */
  function _setDispatcher(ISingleMessageDispatcher dispatcher_) internal {
    if (address(dispatcher_) == address(0)) revert DispatcherZeroAddress();
    _dispatcher = dispatcher_;
  }

  /**
   * @notice Set the drawManagerReceiver.
   * @param drawManagerReceiver_ Address of the drawManagerReceiver
   */
  function _setDrawManagerReceiver(address drawManagerReceiver_) internal {
    if (drawManagerReceiver_ == address(0)) revert DrawManagerReceiverZeroAddress();
    _drawManagerReceiver = drawManagerReceiver_;
  }
}
