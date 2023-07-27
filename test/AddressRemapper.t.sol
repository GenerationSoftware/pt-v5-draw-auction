// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import { AddressRemapperHarness } from "test/harness/AddressRemapperHarness.sol";

contract AddressRemapperTest is Test {
  /* ============ Events ============ */

  event AddressRemapped(address indexed caller, address indexed destination);

  /* ============ Variables ============ */

  AddressRemapperHarness public addressRemapper;

  function setUp() public {
    addressRemapper = new AddressRemapperHarness();
  }

  /* ============ _remap ============ */

  function testRemap() public {
    address _bob = address(1);
    address _destination = address(2);

    vm.expectEmit();
    emit AddressRemapped(_bob, _destination);

    addressRemapper.remap(_bob, _destination);

    assertEq(addressRemapper.remappingOf(_bob), _destination);
  }

  function testRemapClear() public {
    address _bob = address(1);
    address _destination = address(2);

    assertEq(addressRemapper.remappingOf(_bob), _bob); // no remapping set

    addressRemapper.remap(_bob, _destination);
    assertEq(addressRemapper.remappingOf(_bob), _destination); // remapping set

    addressRemapper.remap(_bob, address(0)); // remapping cleared
    assertEq(addressRemapper.remappingOf(_bob), _bob);
  }

  function testRemapToSelf() public {
    address _bob = address(1);
    address _destination = address(2);

    addressRemapper.remap(_bob, _destination);
    assertEq(addressRemapper.remappingOf(_bob), _destination); // remapping set

    addressRemapper.remap(_bob, _bob); // remapping to self
    assertEq(addressRemapper.remappingOf(_bob), _bob);
  }

  /* ============ remappingOf ============ */

  function testRemappingOfDefault() public {
    assertEq(addressRemapper.remappingOf(address(123)), address(123));
    assertEq(addressRemapper.remappingOf(address(0)), address(0));
  }

  /* ============ remapTo ============ */

  function testRemapTo() public {
    address _bob = address(1);
    address _destination = address(2);

    vm.expectEmit();
    emit AddressRemapped(_bob, _destination);

    vm.startPrank(_bob);
    addressRemapper.remapTo(_destination);

    assertEq(addressRemapper.remappingOf(_bob), _destination);

    vm.stopPrank();
  }
}
