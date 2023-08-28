// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import { AddressRemapper } from "../src/abstract/AddressRemapper.sol";

contract AddressRemapperTest is Test {
  /* ============ Events ============ */

  event AddressRemapped(address indexed caller, address indexed destination);

  /* ============ Variables ============ */

  AddressRemapper public addressRemapper;

  function setUp() public {
    addressRemapper = new AddressRemapper();
  }

  /* ============ _remap ============ */

  function testRemap() public {
    address bob = makeAddr("bob");
    address alice = makeAddr("alice");

    vm.expectEmit();
    emit AddressRemapped(bob, alice);

    vm.prank(bob);
    addressRemapper.remapTo(alice);

    assertEq(addressRemapper.remappingOf(bob), alice);
  }

  function testRemapClear() public {
    address bob = makeAddr("bob");
    address alice = makeAddr("alice");

    assertEq(addressRemapper.remappingOf(bob), bob); // no remapping set

    vm.prank(bob);
    addressRemapper.remapTo(alice);
    assertEq(addressRemapper.remappingOf(bob), alice); // remapping set

    vm.prank(bob);
    addressRemapper.remapTo(address(0)); // remapping cleared
    assertEq(addressRemapper.remappingOf(bob), bob);
  }

  function testRemapToSelf() public {
    address bob = makeAddr("bob");
    address alice = makeAddr("alice");

    vm.prank(bob);
    addressRemapper.remapTo(alice);
    assertEq(addressRemapper.remappingOf(bob), alice); // remapping set

    vm.prank(bob);
    addressRemapper.remapTo(bob); // remapping to self
    assertEq(addressRemapper.remappingOf(bob), bob);
  }

  /* ============ remappingOf ============ */

  function testRemappingOfDefault() public {
    assertEq(addressRemapper.remappingOf(address(123)), address(123));
    assertEq(addressRemapper.remappingOf(address(0)), address(0));
  }

  /* ============ remapTo ============ */

  function testRemapTo() public {
    address bob = makeAddr("bob");
    address alice = makeAddr("alice");

    vm.expectEmit();
    emit AddressRemapped(bob, alice);

    vm.startPrank(bob);
    addressRemapper.remapTo(alice);

    assertEq(addressRemapper.remappingOf(bob), alice);

    vm.stopPrank();
  }
}
