// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {MockUsdStable} from "../src/core/MockUSDStable.sol"; // adjust path if needed

contract MockUSDStableTest is Test {
    MockUsdStable mockUsdStable;
    address user = address(0xBEEF);

    function setUp() public {
        // deploy with initial mint to this contract
        mockUsdStable = new MockUsdStable(address(this), 1000 ether);
    }

    /// @notice Verify initial setup
    function testInitialSetup() public view{
        assertEq(mockUsdStable.name(), "USD Stable Mock");
        assertEq(mockUsdStable.symbol(), "MUSD");
        assertEq(mockUsdStable.balanceOf(address(this)), 1000 ether);
        assertEq(mockUsdStable.totalSupply(), 1000 ether);
    }

    /// @notice Ensure anyone can mint new tokens
    function testAnyoneCanMint() public {
        vm.prank(user);
        mockUsdStable.mint(user, 500 ether);

        assertEq(mockUsdStable.balanceOf(user), 500 ether);
        assertEq(mockUsdStable.totalSupply(), 1500 ether);
    }

    /// @notice Minting to zero address should revert
    function testMintToZeroAddressReverts() public {
        vm.expectRevert(); // ERC20 will revert internally with "ERC20: mint to the zero address"
        mockUsdStable.mint(address(0), 10 ether);
    }

    /// @notice Test multiple mints accumulate properly
    function testMultipleMints() public {
        mockUsdStable.mint(user, 100 ether);
        mockUsdStable.mint(user, 200 ether);

        assertEq(mockUsdStable.balanceOf(user), 300 ether);
        assertEq(mockUsdStable.totalSupply(), 1300 ether);
    }
}
