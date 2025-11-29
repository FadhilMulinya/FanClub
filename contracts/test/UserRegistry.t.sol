// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {UserRegistry} from "../src/core/UserRegistry.sol";
import {IUserRegistry} from "../src/interfaces/IUserRegistry.sol";


contract UserRegistryTest is Test  {
    UserRegistry userRegistry;

    address user1 = address(0x111);
    address user2 = address(0x222);
    bytes32 hash1 = keccak256("kyc_verified");
    bytes32 hash2 = keccak256("aml_verified");


    function setUp() public {
        userRegistry = new UserRegistry();
    }

    // --- updateUser() tests ---

    function testUpdateUserStoresData() public {
        userRegistry.updateUser(user1, 40, hash1, true);

        (
            uint8 riskScore,
            bytes32 attestationHash,
            uint256 lastUpdated,
            bool isVerified,
            bytes32 attestationType
        ) = userRegistry.mUserCompliance(user1);

        assertEq(riskScore, 40);
        assertEq(attestationHash, hash1);
        assertEq(isVerified, true);
        assertEq(attestationType, bytes32(0));
        assertGt(lastUpdated, 0);
    }

    function testUpdateUserEmitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit IUserRegistry.UserComplianceUpdated(user1, 30, hash1, true);
        userRegistry.updateUser(user1, 30, hash1, true);
    }

    function testUpdateUserRevertsZeroAddress() public {
        vm.expectRevert("The address cant be zero address");
        userRegistry.updateUser(address(0), 20, hash1, true);
    }

    function testUpdateUserRevertsInvalidRiskScore() public {
        vm.expectRevert(IUserRegistry.InvalidRiskScore.selector);
        userRegistry.updateUser(user1, 150, hash1, true);
    }

    function testUpdateUserRevertsZeroHash() public {
        vm.expectRevert("The attestation hash can not be zero");
        userRegistry.updateUser(user1, 40, bytes32(0), true);
    }

    // --- Overwrite update tests ---

    function testUpdateUserOverwriteUpdatesValuesAndTimestamp() public {
        // initial update
        userRegistry.updateUser(user1, 30, hash1, true);
        (, , uint256 oldTimestamp, , ) = userRegistry.mUserCompliance(user1);

        // warp forward and overwrite
        vm.warp(block.timestamp + 100);
        userRegistry.updateUser(user1, 80, hash2, false);

        (
            uint8 riskScore,
            bytes32 attestationHash,
            uint256 lastUpdated,
            bool isVerified,
            bytes32 attestationType
        ) = userRegistry.mUserCompliance(user1);

        // ensure values changed
        assertEq(riskScore, 80, "Risk score should update");
        assertEq(attestationHash, hash2, "Hash should update");
        assertEq(isVerified, false, "Verification status should update");
        assertEq(attestationType, bytes32(0));
        assertGt(lastUpdated, oldTimestamp, "Timestamp should be refreshed");
    }

    function testUpdateUserOverwriteEmitsNewEvent() public {
        userRegistry.updateUser(user1, 25, hash1, true);

        vm.expectEmit(true, false, false, true);
        emit IUserRegistry.UserComplianceUpdated(user1, 70, hash2, false);
        userRegistry.updateUser(user1, 70, hash2, false);
    }

    // --- getUser() tests ---

    function testGetUserReturnsData() public {
        userRegistry.updateUser(user1, 40, hash1, true);
        UserRegistry.UserCompliance memory u = userRegistry.getUser(user1);

        assertEq(u.riskScore, 40);
        assertEq(u.attestationHash, hash1);
        assertEq(u.isVerified, true);
    }

    function testGetUserRevertsIfNotExists() public {
        vm.expectRevert(IUserRegistry.UserNotFound.selector);
        userRegistry.getUser(user1);
    }

    function testGetUserRevertsZeroAddress() public {
        vm.expectRevert("The address cant be zero address");
        userRegistry.getUser(address(0));
    }

    // --- isCompliant() tests ---

    function testIsCompliantTrueForVerifiedLowRisk() public {
        userRegistry.updateUser(user1, 45, hash1, true);
        bool compliant = userRegistry.isCompliant(user1);
        assertTrue(compliant);
    }

    function testIsCompliantFalseForHighRisk() public {
        userRegistry.updateUser(user1, 70, hash1, true);
        bool compliant = userRegistry.isCompliant(user1);
        assertFalse(compliant);
    }

    function testIsCompliantFalseForUnverified() public {
        userRegistry.updateUser(user1, 30, hash1, false);
        bool compliant = userRegistry.isCompliant(user1);
        assertFalse(compliant);
    }

    function testIsCompliantRevertsForUnknownUser() public {
        vm.expectRevert(IUserRegistry.UserNotFound.selector);
        userRegistry.isCompliant(user1);
    }

    // --- getRiskScore() tests ---

    function testGetRiskScoreReturnsValue() public {
        userRegistry.updateUser(user1, 10, hash1, true);
        assertEq(userRegistry.getRiskScore(user1), 10);
    }

    function testGetRiskScoreRevertsIfUserNotFound() public {
        vm.expectRevert(IUserRegistry.UserNotFound.selector);
        userRegistry.getRiskScore(user1);
    }

    // --- getAttestationHash() tests ---

    function testGetAttestationHashReturnsValue() public {
        userRegistry.updateUser(user1, 25, hash2, true);
        assertEq(userRegistry.getAttestationHash(user1), hash2);
    }

    function testGetAttestationHashRevertsIfUserNotFound() public {
        vm.expectRevert(IUserRegistry.UserNotFound.selector);
        userRegistry.getAttestationHash(user1);
    }
}
