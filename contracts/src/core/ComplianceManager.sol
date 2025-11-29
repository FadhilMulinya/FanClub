//SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IComplianceManager} from "../interfaces/IComplianceManager.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {UserRegistry} from "./UserRegistry.sol";

/**
 * @title ComplianceManager
 * @notice Manages user compliance, risk scoring, and attestations for the protocol
 * @dev Implements UUPS upgradeability pattern
 */
contract ComplianceManager is 
    IComplianceManager,
    Initializable,
    AccessControlUpgradeable, 
    PausableUpgradeable,
    UUPSUpgradeable,
    UserRegistry 
{
    
    bytes32 public constant ADMIN = keccak256("ADMIN");
    bytes32 public constant COMPLIANCE_OFFICER = keccak256("COMPLIANCE_OFFICER");
    bytes32 public constant UPGRADER = keccak256("UPGRADER");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(bool testMode) {
        if (!testMode) _disableInitializers();
    }


    /**
     * @notice Initialize the contract (replaces constructor)
     * @param _admin Address of the admin
     * @param _complianceOfficer Address of the compliance officer
     * @param _upgrader Address with upgrade permissions
     */
    function initialize(
        address _admin,
        address _complianceOfficer,
        address _upgrader
    ) external initializer {
        require(_admin != address(0), "Invalid admin address");
        require(_complianceOfficer != address(0), "Invalid compliance officer address");
        require(_upgrader != address(0), "Invalid upgrader address");

        // Initialize parent contracts (UUPSUpgradeable has no init function)
        __AccessControl_init();
        __Pausable_init();
        
        // Grant roles
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN, _admin);
        _grantRole(COMPLIANCE_OFFICER, _complianceOfficer);
        _grantRole(UPGRADER, _upgrader);
    }

    /**
     * @notice Update a user's risk score
     * @param _user Address of the user
     * @param _newRiskScore New risk score (0-100)
     */
    function updateUserRisk(address _user, uint8 _newRiskScore) 
        external 
        onlyRole(ADMIN) 
        whenNotPaused 
    {
        require(_newRiskScore <= 100, "Risk score must be between 0-100");
        require(_user != address(0), "Invalid user address");

        UserCompliance storage user = mUserCompliance[_user];

        user.riskScore = _newRiskScore;
        user.lastUpdated = block.timestamp;

        emit IComplianceManager.UserRiskUpdated(_user, _newRiskScore, msg.sender, block.timestamp);
    }

    /**
     * @notice Record an attestation for a user
     * @param _user Address of the user
     * @param _attestationHash Hash of the attestation document
     * @param _attestationType Type identifier
     */
    function recordAttestation(
        address _user,
        bytes32 _attestationHash,
        bytes32 _attestationType
    ) external override onlyRole(COMPLIANCE_OFFICER) whenNotPaused {
        require(_user != address(0), "Invalid user address");
        require(_attestationHash != bytes32(0), "Invalid attestation hash");
        require(_attestationType != bytes32(0), "Invalid attestation type");

        UserCompliance storage userData = mUserCompliance[_user];

        userData.attestationHash = _attestationHash;
        userData.attestationType = _attestationType;
        userData.lastUpdated = block.timestamp;

        emit AttestationRecorded(_user, _attestationHash, _attestationType, msg.sender);
    }

    /**
     * @notice Check if a user is compliant for operations
     * @param _user Address to check
     * @return bool True if user meets compliance requirements
     */
    function isCompliant(address _user) 
        external 
        view 
        override(UserRegistry, IComplianceManager) 
        returns (bool) 
    {
        UserCompliance memory userData = mUserCompliance[_user];
        if (userData.lastUpdated == 0) revert UserNotFound();
        return userData.isVerified && userData.riskScore <= 50;
    }

    /**
     * @notice Get the ADMIN role identifier
     * @return bytes32 The ADMIN role hash
     */
    function getAdminRole() external pure returns (bytes32) {
        return ADMIN;
    }

    /**
     * @notice Pause all compliance operations
     * @dev Only callable by ADMIN role
     */
    function pause() external onlyRole(ADMIN) {
        _pause();
    }

    /**
     * @notice Resume compliance operations
     * @dev Only callable by ADMIN role
     */
    function unpause() external onlyRole(ADMIN) {
        _unpause();
    }

    /**
     * @dev Authorize upgrade to new implementation
     * @param newImplementation Address of the new implementation
     */
    function _authorizeUpgrade(address newImplementation) 
        internal 
        view
        override 
        onlyRole(UPGRADER) 
    {
        require(newImplementation != address(0), "Invalid implementation address");
    }

    function upgradeTo(address newImplementation) public {
    upgradeToAndCall(newImplementation, "");
}

    

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}