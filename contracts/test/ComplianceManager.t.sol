// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {ComplianceManager} from "../src/core/ComplianceManager.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";


contract ComplianceManagerTest is Test {
    ComplianceManager implementation;
    ComplianceManager complianceManager;

    address admin = address(0xA11CE);
    address officer = address(0xB0B);
    address upgrader = address(0xC0DE);
    address user = address(0xD00D);

    function setUp() public {
        // Deploy implementation
        implementation = new ComplianceManager(false);

        // Encode initializer
        bytes memory data = abi.encodeWithSelector(
            ComplianceManager.initialize.selector,
            admin,
            officer,
            upgrader
        );

        // Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);
        complianceManager = ComplianceManager(address(proxy));
    }

    /*//////////////////////////////////////////////////////////////
                              INITIALIZATION
    //////////////////////////////////////////////////////////////*/
    function testInitialization() public view {
        assertTrue(complianceManager.hasRole(complianceManager.ADMIN(), admin));
        assertTrue(complianceManager.hasRole(complianceManager.COMPLIANCE_OFFICER(), officer));
        assertTrue(complianceManager.hasRole(complianceManager.UPGRADER(), upgrader));
    }

    /*//////////////////////////////////////////////////////////////
                             USER UPDATE LOGIC
    //////////////////////////////////////////////////////////////*/
    function testUpdateUserViaRegistry() public {
        bytes32 hash = keccak256("kyc-doc");
        vm.prank(admin);
        complianceManager.updateUser(user, 45, hash, true);

        (uint8 risk,, , bool verified,) = complianceManager.mUserCompliance(user);
        assertEq(risk, 45);
        assertTrue(verified);
    }

    function test_RevertWhen_UpdateUserInvalidRisk() public {
        vm.prank(admin);
        vm.expectRevert(); // should revert due to invalid risk > 100
        complianceManager.updateUser(user, 150, keccak256("kyc-doc"), true);
    }

    /*//////////////////////////////////////////////////////////////
                             RISK SCORE UPDATE
    //////////////////////////////////////////////////////////////*/
    function testUpdateUserRisk() public {
        bytes32 hash = keccak256("kyc-doc");
        vm.startPrank(admin);
        complianceManager.updateUser(user, 30, hash, true);
        complianceManager.updateUserRisk(user, 40);
        vm.stopPrank();

        (uint8 riskScore, , , , ) = complianceManager.mUserCompliance(user);
        assertEq(riskScore, 40);
    }

    function test_RevertWhen_UpdateUserRiskNotAdmin() public {
        vm.prank(user);
        vm.expectRevert(); // missing ADMIN role
        complianceManager.updateUserRisk(user, 25);
    }

    /*//////////////////////////////////////////////////////////////
                             ATTESTATION RECORD
    //////////////////////////////////////////////////////////////*/
    function testRecordAttestationByOfficer() public {
        bytes32 hash = keccak256("kyc-doc");
        vm.prank(admin);
        complianceManager.updateUser(user, 40, hash, true);

        bytes32 attHash = keccak256("attestation-123");
        bytes32 attType = keccak256("kyc-check");

        vm.prank(officer);
        complianceManager.recordAttestation(user, attHash, attType);

        bytes32 storedHash = complianceManager.getAttestationHash(user);
        assertEq(storedHash, attHash);
    }

    function test_RevertWhen_RecordAttestationByNonOfficer() public {
        bytes32 hash = keccak256("kyc-doc");
        vm.prank(admin);
        complianceManager.updateUser(user, 40, hash, true);

        vm.prank(user);
        vm.expectRevert(); // must have COMPLIANCE_OFFICER role
        complianceManager.recordAttestation(user, keccak256("att"), keccak256("type"));
    }

    /*//////////////////////////////////////////////////////////////
                                PAUSING
    //////////////////////////////////////////////////////////////*/
    function testPauseAndUnpause() public {
        vm.startPrank(admin);
        complianceManager.pause();
        assertTrue(complianceManager.paused());

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        complianceManager.updateUserRisk(user, 20);

        complianceManager.unpause();
        assertFalse(complianceManager.paused());
        vm.stopPrank();
    }

/*//////////////////////////////////////////////////////////////
                                 UPGRADE
//////////////////////////////////////////////////////////////*/
function testUpgradeByAuthorizedUpgrader() public {
    ComplianceManager newImpl = new ComplianceManager(false);

    // call via proxy as upgrader
    vm.prank(upgrader);
    complianceManager.upgradeTo(address(newImpl));

    // Verify implementation slot changed
    bytes32 implSlot = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
    address newImplementation = address(uint160(uint256(vm.load(address(complianceManager), implSlot))));
    assertEq(newImplementation, address(newImpl));
}

function test_RevertWhen_UpgradeCalledByNonUpgrader() public {
    ComplianceManager newImpl = new ComplianceManager(false);
    vm.prank(user);
    vm.expectRevert(); // authorization will fail in _authorizeUpgrade
    complianceManager.upgradeTo(address(newImpl));
}

function test_RevertWhen_UpgradeToZeroAddress() public {
    vm.prank(upgrader);
    vm.expectRevert("Invalid implementation address");
    complianceManager.upgradeTo(address(0));
}

}
