// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { AddressRemapper } from "local-draw-auction/abstract/AddressRemapper.sol";

contract AddressRemapperHarness is AddressRemapper {
  function remap(address _caller, address _destination) external {
    _remap(_caller, _destination);
  }
}
