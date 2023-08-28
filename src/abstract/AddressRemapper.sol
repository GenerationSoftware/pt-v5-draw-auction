// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title AddressRemapper
 * @author G9 Software Inc.
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
   * @param _addr The address to check for remappings
   * @dev If the address does not have a remapping, the input address will be returned.
   * @return The remapped destination address for `_addr`
   */
  function remappingOf(address _addr) public view returns (address) {
    if (_destinationAddress[_addr] == address(0)) {
      return _addr;
    } else {
      return _destinationAddress[_addr];
    }
  }

  /* ============ External Functions ============ */

  /**
   * @notice Remaps the caller's address to the specified destination address
   * @param _destination The destination address to remap caller to
   * @dev Reset the destination to the zero address to remove the remapping.
   */
  function remapTo(address _destination) external {
    if (_destination == address(0) || _destination == msg.sender) {
      delete _destinationAddress[msg.sender];
      emit AddressRemapped(msg.sender, msg.sender);
    } else {
      _destinationAddress[msg.sender] = _destination;
      emit AddressRemapped(msg.sender, _destination);
    }
  }
}
