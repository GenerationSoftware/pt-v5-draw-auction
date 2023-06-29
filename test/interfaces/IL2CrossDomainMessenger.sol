// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

/**
 * @custom:proxied
 * @custom:predeploy 0x4200000000000000000000000000000000000007
 * @title L2CrossDomainMessenger
 * @notice The L2CrossDomainMessenger is a high-level interface for message passing between L1 and
 *         L2 on the L2 side. Users are generally encouraged to use this contract instead of lower
 *         level message passing contracts.
 */
interface IL2CrossDomainMessenger {
  /**
   * @notice Relays a message that was sent by the other CrossDomainMessenger contract. Can only
   *         be executed via cross-chain call from the other messenger OR if the message was
   *         already received once and is currently being replayed.
   *
   * @param _nonce       Nonce of the message being relayed.
   * @param _sender      Address of the user who sent the message.
   * @param _target      Address that the message is targeted at.
   * @param _value       ETH value to send with the message.
   * @param _minGasLimit Minimum amount of gas that the message can be executed with.
   * @param _message     Message to send to the target.
   */
  function relayMessage(
    uint256 _nonce,
    address _sender,
    address _target,
    uint256 _value,
    uint256 _minGasLimit,
    bytes calldata _message
  ) external payable;

  /**
   * @notice Retrieves the next message nonce. Message version will be added to the upper two
   *         bytes of the message nonce. Message version allows us to treat messages as having
   *         different structures.
   *
   * @return Nonce of the next message to be sent, with added message version.
   */
  function messageNonce() external view returns (uint256);
}
