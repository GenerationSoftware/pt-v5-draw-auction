// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title AddressRemapper
 * @author Generation Software Team
 * @notice Allows addresses to provide a remapping to a new address.
 * @dev The RngAuction lives on L1, but the rewards are given out on L2s. This contract allows the L1 reward recipients to remap their addresses to their L2 addresses if needed.
 */
contract AddressRemapper {
  /* ============ Variables ============ */

  /// @notice User-defined address remapping
  mapping(address => address) internal _destinationAddress;

  /* ============ Events ============ */

  /**
   @notice Emitted when a remapping is set.
   @param caller Caller address
   @param destination Remapped destination address that will be used in place of the caller address
   */
  event AddressRemapped(address indexed caller, address indexed destination);

  /* ============ Public Functions ============ */

  /**
   * @notice Retrieves the remapping for the given address.
   * @dev If the address does not have a remapping, the input address will be returned.
   * @return The remapped destination address
   */
  function remappingOf(address _addr) public view returns (address) {
    address destAddr = _destinationAddress[_addr];
    return destAddr != address(0) ? destAddr : _addr;
  }

  /* ============ External Functions ============ */

  /**
   * @notice Remaps the caller's address to the specified destination address
   * @param _destination The destination address to remap caller to
   * @dev Reset the destination to the zero address to remove the remapping.
   */
  function remapTo(address _destination) external {
    _remap(msg.sender, _destination);
  }

  /* ============ Internal Functions ============ */

  /**
   * @notice Remaps a caller address to the specified destination address
   * @param _caller The caller address
   * @param _destination The destination address to remap caller to
   */
  function _remap(address _caller, address _destination) internal {
    _destinationAddress[_caller] = _destination;
    emit AddressRemapped(_caller, _destination);
  }
}
