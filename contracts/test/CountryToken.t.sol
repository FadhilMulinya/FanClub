// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {CountryToken} from "../src/core/CountryToken.sol"; 

contract CountryTokenTest is Test {
    CountryToken token;
    address escrow = address(0x1234);
    address user = address(0x5678);

    function setUp() public {
        token = new CountryToken(escrow);
    }

    /// @notice Test that constructor sets correct name, symbol, and grants MINTER_ROLE
    function testInitialSetup() public view {
        assertEq(token.name(), "Kenya Shilling Token");
        assertEq(token.symbol(), "KES");

        bytes32 minterRole = token.MINTER_ROLE();
        assertTrue(token.hasRole(minterRole, escrow), "Escrow should have MINTER_ROLE");
    }

    /// @notice Ensure only Escrow can mint
    function testOnlyEscrowCanMint() public {
        vm.expectRevert(); // should revert since caller isn't escrow
        token.mint(user, 100);
    }

    /// @notice Test minting tokens by escrow (valid role)
    function testMintByEscrow() public {
        vm.prank(escrow);
        bool success = token.mint(user, 100);
        assertTrue(success, "Mint should return true");

        uint256 expectedAmount = 100 * 10 ** token.decimals();
        assertEq(token.balanceOf(user), expectedAmount, "User should have minted amount");
        assertEq(token.totalSupply(), expectedAmount, "Total supply should match minted amount");
    }

    /// @notice Mint should revert if zero address
    function testMintToZeroAddressShouldRevert() public {
        vm.prank(escrow);
        vm.expectRevert("Cant mint to zero address");
        token.mint(address(0), 100);
    }

    /// @notice Mint should revert if zero value
    function testMintZeroValueShouldRevert() public {
        vm.prank(escrow);
        vm.expectRevert("Cant mint zero tokens");
        token.mint(user, 0);
    }

    /// @notice Test multiple mints accumulate correctly
    function testMultipleMintsAccumulateSupply() public {
        vm.startPrank(escrow);
        token.mint(user, 50);
        token.mint(user, 150);
        vm.stopPrank();

        uint256 expected = (50 + 150) * 10 ** token.decimals();
        assertEq(token.balanceOf(user), expected);
        assertEq(token.totalSupply(), expected);
    }
}
