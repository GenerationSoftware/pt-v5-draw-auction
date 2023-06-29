// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { PrizePool } from "v5-prize-pool/PrizePool.sol";

import { Auction, AuctionLib } from "src/auctions/Auction.sol";
import { TwoStepsAuction, RNGInterface } from "src/auctions/TwoStepsAuction.sol";
import { ISingleMessageDispatcher } from "src/interfaces/ISingleMessageDispatcher.sol";
import { RewardLib } from "src/libraries/RewardLib.sol";

/**
 * @title PoolTogether V5 DrawAuctionDispatcher
 * @author PoolTogether Inc. Team
 * @notice The DrawAuctionDispatcher uses an auction mechanism to incentivize the completion of the Draw.
 *         This mechanism relies on a linear interpolation to incentivizes anyone to start and complete the Draw.
 *         The first user to complete the Draw gets rewarded with the partial or full PrizePool reserve amount.
 */
contract DrawAuctionDispatcher is TwoStepsAuction {
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
    AuctionLib.Phase[] phases,
    uint256 randomNumber
  );

  /* ============ Custom Errors ============ */

  /// @notice Thrown when the Dispatcher address passed to the constructor is zero address.
  error DispatcherZeroAddress();

  /// @notice Thrown when the toChainId passed to the constructor is zero.
  error ToChainIdZero();

  /// @notice Thrown when the DrawAuctionExecutor address passed to the constructor is zero address.
  error DrawAuctionExecutorZeroAddress();

  /* ============ Variables ============ */

  /// @notice Instance of the dispatcher on Ethereum
  ISingleMessageDispatcher internal _dispatcher;

  /// @notice ID of the receiving chain
  uint256 internal immutable _toChainId;

  /// @notice Address of the DrawAuctionExecutor to compute Draw for.
  address internal _drawAuctionExecutor;

  /* ============ Constructor ============ */

  /**
   * @notice Contract constructor.
   * @param dispatcher_ Instance of the dispatcher on Ethereum that will dispatch the phases and random number
   * @param toChainId_ ID of the receiving chain
   * @param rng_ Instance of the RNG service
   * @param rngTimeout_ Time in seconds before an RNG request can be cancelled
   * @param _auctionPhases Number of auction phases
   * @param auctionDuration_ Duration of the auction in seconds
   * @param _owner Address of the DrawAuctionDispatcher owner
   */
  constructor(
    ISingleMessageDispatcher dispatcher_,
    uint256 toChainId_,
    RNGInterface rng_,
    uint32 rngTimeout_,
    uint8 _auctionPhases,
    uint32 auctionDuration_,
    address _owner
  ) TwoStepsAuction(rng_, rngTimeout_, _auctionPhases, auctionDuration_, _owner) {
    _setDispatcher(dispatcher_);

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

  /* ============ Internal Functions ============ */

  /* ============ Hooks ============ */

  /**
   * @notice Hook called after the auction has ended.
   * @param _auctionPhases Array of auction phases
   * @param _randomNumber Random number generated by the RNG service
   */
  function _afterAuctionEnds(
    AuctionLib.Phase[] memory _auctionPhases,
    uint256 _randomNumber
  ) internal override {
    _dispatcher.dispatchMessage(
      _toChainId,
      _drawAuctionExecutor,
      abi.encodeWithSignature(
        "completeAuction((uint8,uint64,uint64,address)[],uint32,uint256)",
        _auctionPhases,
        _auctionDuration,
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
}
