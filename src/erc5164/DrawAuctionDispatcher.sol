// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { PrizePool } from "v5-prize-pool/PrizePool.sol";

import { PhaseManager, Phase } from "src/abstract/PhaseManager.sol";
import { ISingleMessageDispatcher } from "src/interfaces/ISingleMessageDispatcher.sol";
import { RewardLib } from "src/libraries/RewardLib.sol";
import { OnlyPhaseManager, IDrawAuction } from "src/interfaces/IDrawAuction.sol";
import { Ownable } from "owner-manager/Ownable.sol";

/**
 * @title PoolTogether V5 DrawAuctionDispatcher
 * @author PoolTogether Inc. Team
 * @notice The DrawAuctionDispatcher uses an auction mechanism to incentivize the completion of the Draw.
 *         This mechanism relies on a linear interpolation to incentivizes anyone to start and complete the Draw.
 *         The first user to complete the Draw gets rewarded with the partial or full PrizePool reserve amount.
 */
contract DrawAuctionDispatcher is Ownable, IDrawAuction {
  /* ============ Events ============ */

  /**
   * @notice Event emitted when the dispatcher is set.
   * @param dispatcher Instance of the dispatcher on Ethereum that will dispatch the phases and random number
   */
  event DispatcherSet(ISingleMessageDispatcher indexed dispatcher);

  /**
   * @notice Event emitted when the drawAuctionExecutor is set.
   * @param drawAuctionExecutor Address of the drawAuctionExecutor on the receiving chain that will complete the Draw
   */
  event DrawAuctionExecutorSet(address indexed drawAuctionExecutor);

  /**
   * @notice Event emitted when the phaseManager is set.
   * @param phaseManager Address of the phaseManager on the receiving chain that will complete the Draw
   */
  event PhaseManagerSet(address indexed phaseManager);

  /**
   * @notice Event emitted when the RNG and auction phases have been dispatched.
   * @param dispatcher Instance of the dispatcher on Ethereum that dispatched the phases and random number
   * @param toChainId ID of the receiving chain
   * @param drawAuctionExecutor Address of the DrawAuctionExecutor on the receiving chain that will award the auction and complete the Draw
   * @param phases Array of auction phases
   * @param randomNumber Random number computed by the RNG
   */
  event AuctionDispatched(
    ISingleMessageDispatcher indexed dispatcher,
    uint256 indexed toChainId,
    address indexed drawAuctionExecutor,
    Phase[] phases,
    uint256 randomNumber
  );

  /* ============ Custom Errors ============ */

  /// @notice Thrown when the Dispatcher address passed to the constructor is zero address.
  error DispatcherZeroAddress();

  /// @notice Thrown when the toChainId passed to the constructor is zero.
  error ToChainIdZero();

  /// @notice Thrown when the DrawAuctionExecutor address passed to the constructor is zero address.
  error DrawAuctionExecutorZeroAddress();

  /// @notice Thrown when the DrawAuctionExecutor address passed to the constructor is zero address.
  error PhaseManagerZeroAddress();

  /* ============ Variables ============ */

  /// @notice Instance of the dispatcher on Ethereum
  ISingleMessageDispatcher internal _dispatcher;

  /// @notice ID of the receiving chain
  uint256 internal immutable _toChainId;

  /// @notice Address of the DrawAuctionExecutor to compute Draw for.
  address internal _drawAuctionExecutor;

  /// @notice The phase manager that can call this contract
  address internal _phaseManager;

  /* ============ Constructor ============ */

  /**
   * @notice Contract constructor.
   * @param dispatcher_ Instance of the dispatcher on Ethereum that will dispatch the phases and random number
   * @param toChainId_ ID of the receiving chain
   * @param _owner Address of the DrawAuctionDispatcher owner
   */
  constructor(
    ISingleMessageDispatcher dispatcher_,
    uint256 toChainId_,
    address phaseManager_,
    address _owner
  ) Ownable(_owner) {
    _setDispatcher(dispatcher_);
    _setPhaseManager(phaseManager_);

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
   * @notice Get the drawAuctionExecutor address on the receiving chain.
   * @return Address of the DrawAuctionExecutor on the receiving chain
   */
  function drawAuctionExecutor() external view returns (address) {
    return _drawAuctionExecutor;
  }

  function phaseManager() external view returns (address) {
    return _phaseManager;
  }

  /**
   * @notice Get the toChainId.
   * @return ID of the receiving chain
   */
  function toChainId() external view returns (uint256) {
    return _toChainId;
  }

  /* ============ Setters ============ */

  /**
   * @notice Set the dispatcher.
   * @dev Only callable by the owner.
   * @param dispatcher_ Address of the dispatcher
   */
  function setDispatcher(ISingleMessageDispatcher dispatcher_) external onlyOwner {
    _setDispatcher(dispatcher_);
  }

  /**
   * @notice Set the drawAuctionExecutor.
   * @dev Only callable by the owner.
   * @param drawAuctionExecutor_ Address of the drawAuctionExecutor
   */
  function setDrawAuctionExecutor(address drawAuctionExecutor_) external onlyOwner {
    _setDrawAuctionExecutor(drawAuctionExecutor_);
  }

  /* ============ IDrawAuction Implementation ============ */

  /**
   * @notice Completes the auction by dispatching the completed phases and random number through the dispatcher
   * @param _auctionPhases Array of auction phases
   * @param _randomNumber Random number generated by the RNG service
   */
  function completeAuction(Phase[] memory _auctionPhases, uint256 _randomNumber) external {
    if (msg.sender != _phaseManager) revert OnlyPhaseManager();

    _dispatcher.dispatchMessage(
      _toChainId,
      _drawAuctionExecutor,
      abi.encodeWithSignature(
        "completeAuction((uint8,uint64,uint64,address)[],uint256)",
        _auctionPhases,
        _randomNumber
      )
    );

    emit AuctionDispatched(
      _dispatcher,
      _toChainId,
      _drawAuctionExecutor,
      _auctionPhases,
      _randomNumber
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
    emit DispatcherSet(dispatcher_);
  }

  /**
   * @notice Set the drawAuctionExecutor.
   * @param drawAuctionExecutor_ Address of the drawAuctionExecutor
   */
  function _setDrawAuctionExecutor(address drawAuctionExecutor_) internal {
    if (drawAuctionExecutor_ == address(0)) revert DrawAuctionExecutorZeroAddress();
    _drawAuctionExecutor = drawAuctionExecutor_;
    emit DrawAuctionExecutorSet(drawAuctionExecutor_);
  }

  /**
   * @notice Set the phaseManager.
   * @param phaseManager_ Address of the phaseManager
   */
  function _setPhaseManager(address phaseManager_) internal {
    if (phaseManager_ == address(0)) revert PhaseManagerZeroAddress();
    _phaseManager = phaseManager_;
    emit PhaseManagerSet(phaseManager_);
  }
}
