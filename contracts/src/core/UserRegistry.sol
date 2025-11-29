//SPDX-License-Identifier:MIT
pragma solidity 0.8.30;
import {IUserRegistry} from "../interfaces/IUserRegistry.sol";

contract UserRegistry is IUserRegistry{

    mapping(address => UserCompliance) public mUserCompliance;

    constructor(){}
     /**
     * @notice Register or update a user's compliance data
     * @param user Address of the user
     * @param riskScore Risk score (0-100)
     * @param attestationHash Hash of compliance documentation
     * @param isVerified Whether user has completed KYC
     */
    function updateUser(
        address user,
        uint8 riskScore,
        bytes32 attestationHash,
        bool isVerified
    ) external  {
        require(user != address(0), "The address cant be zero address");
        if(riskScore > 100 ) revert InvalidRiskScore();
        require(attestationHash != bytes32(0), "The attestation hash can not be zero");

        mUserCompliance[user] = UserCompliance ({
            riskScore: riskScore,
            attestationHash: attestationHash,
            lastUpdated: block.timestamp,
            isVerified:isVerified,
            attestationType: bytes32(0)
        });

        emit UserComplianceUpdated(user,riskScore,attestationHash,isVerified);

    }

    /**
     * @notice Get user compliance data
     * @param user Address to query
     * @return UserCompliance struct with all data
     */
    function getUser(address user) external view override returns (UserCompliance memory){
        require(user != address(0), "The address cant be zero address");

        UserCompliance memory userData = mUserCompliance[user];
        if(userData.lastUpdated == 0) revert UserNotFound();

        return userData;
    }

    /**
     * @notice Check if user is compliant (verified + acceptable risk)
     * @param user Address to check
     * @return bool True if compliant
     */
    function isCompliant(address user) external view virtual returns (bool){
        require(user != address(0), "The address cant be zero address");
        UserCompliance memory userData = mUserCompliance[user];
        if (userData.lastUpdated == 0) revert UserNotFound();
        return userData.isVerified && userData.riskScore <= 50;
    }

    /**
     * @notice Get user's current risk score
     * @param user Address to query
     * @return uint8 Risk score
     */
    function getRiskScore(address user) external view override returns (uint8){
        require(user != address(0), "The address cant be zero address");
        UserCompliance memory userData = mUserCompliance[user];
        if (userData.lastUpdated == 0) revert UserNotFound();
        return userData.riskScore;
    }

    /**
     * @notice Get user's attestation hash
     * @param user Address to query
     * @return bytes32 Attestation hash
     */
    function getAttestationHash(address user) external view override returns (bytes32) {
        require(user != address(0), "The address cant be zero address");
        UserCompliance memory userData = mUserCompliance[user];
        if (userData.lastUpdated == 0) revert UserNotFound();
        return userData.attestationHash;
    }

}