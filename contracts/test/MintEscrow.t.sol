// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {MintEscrow} from "../src/core/MintEscrow.sol";
import {CountryToken} from "../src/core/CountryToken.sol";
import {ComplianceManager} from "../src/core/ComplianceManager.sol";
import {MockUsdStable} from "../src/core/MockUSDStable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MintEscrowTest is Test {
    MintEscrow escrow;
    CountryToken token;
    ComplianceManager compliance;
    MockUsdStable stable;

    address admin = address(1);
    address complianceOfficer = address(2);
    address upgrader = address(3);
    address user = address(4);
    uint256 userInitial = 10_000 ether;

function setUp() public {
    // Deploy ComplianceManager via proxy
    ComplianceManager logic = new ComplianceManager(true);
    ERC1967Proxy proxy = new ERC1967Proxy(
        address(logic),
        abi.encodeWithSelector(
            ComplianceManager.initialize.selector,
            admin,
            complianceOfficer,
            upgrader
        )
    );
    compliance = ComplianceManager(address(proxy));

    // Deploy stable & fund user
    stable = new MockUsdStable(user, userInitial);

    // Deploy as admin to avoid role issues
    vm.startPrank(admin);

    token = new CountryToken(admin);
    escrow = new MintEscrow(
        address(compliance),
        address(stable),
        address(token),
        10_000 ether
    );

    token.grantRole(token.MINTER_ROLE(), address(escrow));

    vm.stopPrank();

    // Approve USD for user
    vm.startPrank(user);
    stable.approve(address(escrow), type(uint256).max);
    vm.stopPrank();
}


    /// ------------------------------------------------------------
    /// ✅ 1. Deployment Sanity
    /// ------------------------------------------------------------
    function testDeployment() public view {
        assertEq(address(compliance).code.length > 0, true);
        assertEq(address(stable).code.length > 0, true);
        assertEq(address(token).code.length > 0, true);
        assertEq(address(escrow).code.length > 0, true);
    }

    /// ------------------------------------------------------------
    /// ✅ 2. Submit Intent (Success)
    /// ------------------------------------------------------------
    function testSubmitIntentSuccess() public {
        vm.startPrank(user);

        bytes32 intentId = escrow.submitIntent(
            100 ether,
            bytes32("KENYA"),
            bytes32("MPESA123")
        );

        vm.stopPrank();

        (address u,, bytes32 countryCode,, uint256 ts, ) = escrow.intents(intentId);

        assertEq(u, user);
        assertEq(countryCode, bytes32("KENYA"));
        assertGt(ts, 0);
    }

    /// ------------------------------------------------------------
    /// ✅ 3. Submit Intent — Reverts if invalid amount
    /// ------------------------------------------------------------
    function testSubmitIntentInvalidAmountReverts() public {
        vm.startPrank(user);
        vm.expectRevert(); // amount < MIN_MINT_AMOUNT
        escrow.submitIntent(0, bytes32("KENYA"), bytes32("TX123"));
        vm.stopPrank();
    }

    /// ------------------------------------------------------------
    /// ✅ 4. Execute Mint (Compliant user)
    /// ------------------------------------------------------------
    function testExecuteMintCompliant() public {
        // Create intent
        vm.startPrank(user);
        bytes32 intentId = escrow.submitIntent(
            100 ether,
            bytes32("KENYA"),
            bytes32("TX456")
        );
        vm.stopPrank();

        // Mark user as compliant manually in UserRegistry (mock)
        // Since ComplianceManager requires internal user data setup,
        // we bypass compliance check using vm.mockCall
        vm.mockCall(
            address(compliance),
            abi.encodeWithSelector(compliance.isCompliant.selector, user),
            abi.encode(true)
        );

        // Execute mint
        vm.startPrank(admin);
        escrow.executeMint(intentId);
        vm.stopPrank();

        // Assert that user got country tokens
        assertGt(token.balanceOf(user), 0);
    }

    /// ------------------------------------------------------------
    /// ✅ 5. Execute Mint (Non-compliant user → Refund)
    /// ------------------------------------------------------------
    function testExecuteMintRefundNonCompliant() public {
        vm.startPrank(user);
        bytes32 intentId = escrow.submitIntent(
            200 ether,
            bytes32("KENYA"),
            bytes32("TX789")
        );
        vm.stopPrank();

        // Mock isCompliant = false
        vm.mockCall(
            address(compliance),
            abi.encodeWithSelector(compliance.isCompliant.selector, user),
            abi.encode(false)
        );

        uint256 beforeBal = stable.balanceOf(user);

        vm.startPrank(admin);
        escrow.executeMint(intentId);
        vm.stopPrank();

        uint256 afterBal = stable.balanceOf(user);
        assertEq(afterBal, beforeBal); // refunded same amount
    }

    /// ------------------------------------------------------------
    /// ✅ 6. Refund Intent (manual by admin)
    /// ------------------------------------------------------------
    function testRefundIntentByAdmin() public {
        vm.startPrank(user);
        bytes32 intentId = escrow.submitIntent(
            50 ether,
            bytes32("UGANDA"),
            bytes32("TX999")
        );
        vm.stopPrank();

        uint256 beforeBal = stable.balanceOf(user);

        vm.startPrank(admin);
        escrow.refundIntent(intentId, "Admin manual refund");
        vm.stopPrank();

        uint256 afterBal = stable.balanceOf(user);
        assertEq(afterBal, beforeBal);
    }

    /// ------------------------------------------------------------
    /// ✅ 7. Setter Functions
    /// ------------------------------------------------------------
    function testSetters() public {
        address newCompliance = address(10);
        address newStable = address(11);
        address newToken = address(12);

        vm.startPrank(admin);
        escrow.setComplianceManager(newCompliance);
        escrow.setStablecoin(newStable);
        escrow.setCountryToken(newToken);
        vm.stopPrank();

        assertEq(address(escrow.complianceManager()), newCompliance);
        assertEq(address(escrow.stablecoin()), newStable);
        assertEq(address(escrow.countryToken()), newToken);
    }

    /// ------------------------------------------------------------
    /// ✅ 8. Reverts — Double Execution
    /// ------------------------------------------------------------
    function testDoubleExecutionReverts() public {
        vm.startPrank(user);
        bytes32 intentId = escrow.submitIntent(
            300 ether,
            bytes32("KENYA"),
            bytes32("TX300")
        );
        vm.stopPrank();

        // Mock compliance true
        vm.mockCall(
            address(compliance),
            abi.encodeWithSelector(compliance.isCompliant.selector, user),
            abi.encode(true)
        );

        vm.startPrank(admin);
        escrow.executeMint(intentId);

        vm.expectRevert(); // should revert on second call
        escrow.executeMint(intentId);
        vm.stopPrank();
    }
}
