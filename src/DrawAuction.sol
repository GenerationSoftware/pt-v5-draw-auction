// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { PrizePool } from "v5-prize-pool/PrizePool.sol";
import { console2 } from "forge-std/Test.sol";

import { Auction } from "src/auctions/Auction.sol";
import { TwoStepsAuction, RNGInterface } from "src/auctions/TwoStepsAuction.sol";
import { RewardLib } from "src/libraries/RewardLib.sol";

/**
 * @title PoolTogether V5 DrawAuction
 * @author PoolTogether Inc. Team
 * @notice The DrawAuction uses an auction mechanism to incentivize the completion of the Draw.
 *         This mechanism relies on a linear interpolation to incentivizes anyone to start and complete the Draw.
 *         The first user to complete the Draw gets rewarded with the partial or full PrizePool reserve amount.
 */
contract DrawAuction is TwoStepsAuction {
  /* ============ Variables ============ */

  /// @notice Instance of the PrizePool to compute Draw for.
  PrizePool internal _prizePool;

  /* ============ Custom Errors ============ */

  /// @notice Thrown when the PrizePool address passed to the constructor is zero address.
  error PrizePoolNotZeroAddress();

  /* ============ Events ============ */

  /**
   * @notice Emitted when a Draw auction phase has completed.
   * @param phaseId Id of the phase
   * @param caller Address of the caller
   */
  event DrawAuctionPhaseCompleted(uint256 indexed phaseId, address indexed caller);

  /**
   * @notice Emitted when a Draw auction has completed and rewards have been distributed.
   * @param phaseIds Ids of the phases that were rewarded
   * @param rewardRecipients Addresses of the rewards recipients per phase id
   * @param rewardAmounts Amounts of rewards distributed per phase id
   */
  event DrawAuctionRewardsDistributed(
    uint8[] phaseIds,
    address[] rewardRecipients,
    uint256[] rewardAmounts
  );

  /* ============ Constructor ============ */

  /**
   * @notice Contract constructor.
   * @param rng_ Address of the RNG service
   * @param rngTimeout_ Time in seconds before an RNG request can be cancelled
   * @param prizePool_ Address of the prize pool
   * @param _auctionPhases Number of auction phases
   * @param auctionDuration_ Duration of the auction in seconds
   * @param _owner Address of the DrawAuction owner
   */
  constructor(
    RNGInterface rng_,
    uint32 rngTimeout_,
    PrizePool prizePool_,
    uint8 _auctionPhases,
    uint256 auctionDuration_,
    address _owner
  ) TwoStepsAuction(rng_, rngTimeout_, _auctionPhases, auctionDuration_, _owner) {
    if (address(prizePool_) == address(0)) revert PrizePoolNotZeroAddress();
    _prizePool = prizePool_;
  }

  /* ============ Getter Functions ============ */

  /**
   * @notice Prize Pool instance for which the Draw is triggered.
   * @return Prize Pool instance
   */
  function prizePool() external view returns (PrizePool) {
    return _prizePool;
  }

  /**
   * @notice Current reward for completing the Auction phase.
   * @param _phaseId ID of the phase to get reward for (i.e. 0 for `startRNGRequest` or 1 for `completeRNGRequest`)
   * @return Reward amount
   */
  function reward(uint8 _phaseId) external view returns (uint256) {
    return RewardLib.getReward(_phases, _phaseId, _prizePool, _auctionDuration);
  }

  /**
   * @notice Hook called after the RNG request has completed.
   * @param _randomNumber The random number that was generated
   */
  function _afterAuctionEnds(uint256 _randomNumber) internal override {
    // Phase memory _startRNGPhase = _getPhase(0);
    // Phase memory _completeRNGPhase = _setPhase(1, _startRNGPhase.startTime, uint64(block.timestamp), _rewardRecipient);
    // uint256 _startRNGRewardAmount = _reward(_startRNGPhase);
    // console2.log("_startRNGRewardAmount", _startRNGRewardAmount);
    // uint256 _completeRNGRewardAmount = _reward(_completeRNGPhase);
    // _prizePool.completeAndStartNextDraw(_randomNumber);
    // if (_startRNGPhase.recipient == _completeRNGPhase.recipient) {
    //   _prizePool.withdrawReserve(_startRNGPhase.recipient, uint104(_startRNGRewardAmount + _completeRNGRewardAmount));
    // } else {
    //   _prizePool.withdrawReserve(_startRNGPhase.recipient, uint104(_startRNGRewardAmount));
    //   _prizePool.withdrawReserve(_completeRNGPhase.recipient, uint104(_completeRNGRewardAmount));
    // }
    // uint8[] memory _phaseIds = new uint8[](2);
    // _phaseIds[0] = _startRNGPhase.id;
    // _phaseIds[1] = _completeRNGPhase.id;
    // address[] memory _rewardRecipients = new address[](2);
    // _rewardRecipients[0] = _startRNGPhase.recipient;
    // _rewardRecipients[1] = _completeRNGPhase.recipient;
    // uint256[] memory _rewardAmounts = new uint256[](2);
    // _rewardAmounts[0] = _startRNGRewardAmount;
    // _rewardAmounts[1] = _completeRNGRewardAmount;
    // emit DrawAuctionPhaseCompleted(1, msg.sender);
    // emit DrawAuctionRewardsDistributed(
    //   _phaseIds,
    //   _rewardRecipients,
    //   _rewardAmounts
    // );
  }
}
