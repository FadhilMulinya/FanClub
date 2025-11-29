//SPDX-License-Identifier:MIT
pragma solidity 0.8.30;

import {IMintEscrow} from "../interfaces/IMintEscrow.sol";
import {MockUsdStable} from "./MockUSDStable.sol";
import {CountryToken} from "./CountryToken.sol";
import {ComplianceManager} from "./ComplianceManager.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title MintEscrow
 * @notice Escrow contract for handling fiat-to-crypto minting with compliance checks
 * @dev Accepts USD stablecoin deposits, checks compliance, and mints country tokens
 * 
 * Requirements:
 * - Accept USD stablecoin deposit intents
 * - Check UserRegistry compliance before minting
 * - Mint country token (1:1 ratio) only if compliant
 * - Prevent double-execution (idempotency)
 * - Handle refunds for non-compliant users
 */
contract MintEscrow is IMintEscrow  , AccessControl , ReentrancyGuard {
    
    
    /// @notice Mapping from intentId to MintIntent
    mapping(bytes32 => MintIntent) public intents;

    /// @notice Mapping from user address to MintLimit
    mapping(address => uint256) public mintedAmount;

    /// @notice ComplianceManager contract address for compliance checks
    ComplianceManager public complianceManager;
    
    /// @notice USD stablecoin contract address
    MockUsdStable public stablecoin;
    
    /// @notice Country token contract address
    CountryToken public countryToken;
    
    /// @notice Minimum mint amount (from seed.json)
    uint256 public immutable MIN_MINT_AMOUNT = 1000000000000000000;
    
    /// @notice Maximum mint amount (from seed.json)
    uint256 public immutable MAX_MINT_AMOUNT = 1000000000000000000000;

    // per-user cap (total minted across time) in wei; if 0, no per-user cap enforced
    uint256 public perUserCap;

    /// @notice The Admin Role

    bytes32 public immutable ADMIN_ROLE;

    // ============ Modifiers ============
    
    modifier validIntent(bytes32 intentId) {
        if (intents[intentId].timestamp == 0) revert IntentNotFound();
        _;
    }

    modifier validUnits(
        uint256 amount,
        bytes32 countryCode,
        bytes32 txRef
    ){
        
        if (amount < MIN_MINT_AMOUNT) revert InvalidAmount();
        if (amount > MAX_MINT_AMOUNT) revert InvalidAmount();
        if (countryCode == bytes32(0)) revert InvalidCountryCode();
        if (txRef == bytes32(0)) revert InvalidTxRef();
        if (perUserCap > 0 && mintedAmount[msg.sender] + amount > perUserCap) revert MintLimitExceeded();

        _;
    }

    // ============ Constructor ============
    
    /**
     * @notice Initialize MintEscrow contract
     * @param _complianceManager Address of UserRegistry/ComplianceManager contract
     * @param _stablecoin Address of USD stablecoin contract
     * @param _countryToken Address of CountryToken contract
     * @param _perUserCap amount a user has minted per day
     */
    constructor(
        address _complianceManager,
        address _stablecoin,
        address _countryToken,
        uint256 _perUserCap
    ) 
    {
        require(_complianceManager != address(0), "MintEscrow: invalid ComplianceManager");
        require(_stablecoin != address(0), "MintEscrow: invalid stablecoin");
        require(_countryToken != address(0), "MintEscrow: invalid countryToken");

        
        
        complianceManager = ComplianceManager(_complianceManager);
        ADMIN_ROLE = complianceManager.getAdminRole();
        stablecoin = MockUsdStable(_stablecoin);
        countryToken = CountryToken(_countryToken);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);

        perUserCap = _perUserCap;
    }

    // ============ Core Functions ============
    
    /**
     * @notice Submit a mint intent
     * @dev User must approve this contract to spend stablecoin before calling
     * @param amount Amount of USD stablecoin to deposit (in wei, 18 decimals)
     * @param countryCode ISO country code for target token (e.g., "KES")
     * @param txRef Off-chain transaction reference (e.g., M-PESA transaction ID)
     * @return intentId Unique identifier for this intent
     */
    function submitIntent(
        uint256 amount,
        bytes32 countryCode,
        bytes32 txRef
    ) external override validUnits(amount,countryCode,txRef) returns (bytes32 intentId) {

        // Generate intentId from user, amount, countryCode, txRef
        // This ensures idempotency - same params = same intentId
        intentId = keccak256(
            abi.encodePacked(
                msg.sender,
                amount,
                countryCode,
                txRef
            )
        );
        
        // Check if intent already exists (prevent double submission)
        if (intents[intentId].timestamp != 0) revert IntentAlreadyExists();
        
        // Transfer stablecoin from user to this contract
        
        bool ok = stablecoin.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();
        
        // Store intent
        intents[intentId] = MintIntent({
            user: msg.sender,
            amount: amount,
            countryCode: countryCode,
            txRef: txRef,
            timestamp: block.timestamp,
            status: MintStatus.Pending
        });
        
        // Emit event
        emit MintIntentSubmitted(intentId, msg.sender, amount, countryCode, txRef);
        
        return intentId;
    }
    
    /**
     * @notice Execute a mint intent (called by authorized callback service)
     * @dev Must check compliance before minting
     * @param intentId Intent to execute
     */
    function executeMint(bytes32 intentId) external override onlyRole(ADMIN_ROLE) validIntent(intentId) nonReentrant {
        MintIntent storage intent = intents[intentId];
        
        // Check if already executed or refunded
        if (intent.status != MintStatus.Pending) revert IntentAlreadyExecuted();
        
        // Check user compliance
        bool compliant = complianceManager.isCompliant(intent.user);
        
        if (!compliant) {
            // Mark as failed and refund
            intent.status = MintStatus.Failed;
            _refundInternal(intentId, "User not compliant");
            return;
        }

        // update per-user minted (enforce perUserCap if set)
        if (perUserCap > 0) {
            if (mintedAmount[intent.user] + intent.amount > perUserCap) revert MintLimitExceeded();
        }
        mintedAmount[intent.user] += intent.amount;
        
        // Mark as executed before external calls (CEI pattern)
        intent.status = MintStatus.Executed;
        
        // Mint country token to user (1:1 ratio)
        // Note: CountryToken.mint() expects value in base units and multiplies by 10^18
        // So we need to pass amount / 10^18
        uint256 tokenAmount = intent.amount / 1e18;
        require(tokenAmount > 0, "MintEscrow: amount too small");
        
        // Call mint function on CountryToken
        bool success = countryToken.mint(intent.user, tokenAmount);
        require(success, "MintEscrow: minting failed");
        
        // Emit event
        emit MintExecuted(
            intentId,
            intent.user,
            intent.amount,
            intent.countryCode,
            intent.txRef
        );
    }
    
    /**
     * @notice Refund a failed or non-compliant intent
     * @param intentId Intent to refund
     * @param reason Reason for refund
     */
    function refundIntent(bytes32 intentId, string calldata reason) external override onlyRole(ADMIN_ROLE) validIntent(intentId) {
        _refundInternal(intentId, reason);
    }
    
    /**
     * @notice Internal refund function
     * @param intentId Intent to refund
     * @param reason Reason for refund
     */
    function _refundInternal(bytes32 intentId, string memory reason) internal {
        MintIntent storage intent = intents[intentId];
        
        // Only allow refund if pending or failed
        require(
            intent.status == MintStatus.Pending || intent.status == MintStatus.Failed,
            "MintEscrow: cannot refund executed intent"
        );
        
        // Mark as refunded
        intent.status = MintStatus.Refunded;
        
        // Transfer stablecoin back to user
        bool ok = stablecoin.transfer(intent.user, intent.amount);
        if (!ok) revert TransferFailed();
        
        // Emit event
        emit MintRefunded(intentId, intent.user, intent.amount, reason);
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Get intent details
     * @param intentId Intent identifier
     * @return MintIntent struct
     */
    function getIntent(bytes32 intentId) external view override returns (MintIntent memory) {
        if (intents[intentId].timestamp == 0) revert IntentNotFound();
        return intents[intentId];
    }
    
    /**
     * @notice Check if an intent exists and its status
     * @param intentId Intent identifier
     * @return status Current status
     */
    function getIntentStatus(bytes32 intentId) external view override returns (MintStatus) {
        if (intents[intentId].timestamp == 0) revert IntentNotFound();
        return intents[intentId].status;
    }
    
    // ============ Admin Functions ============
    
    /**
     * @notice Set the ComplianceManager address
     * @param _complianceManager Address of UserRegistry contract
     */
    function setComplianceManager(address _complianceManager) external override onlyRole(ADMIN_ROLE) {
        require(_complianceManager != address(0), "MintEscrow: invalid registry");
        complianceManager = ComplianceManager(_complianceManager);
    }
    
    /**
     * @notice Set the USD stablecoin address
     * @param token Address of USD stablecoin
     */
    function setStablecoin(address token) external override onlyRole(ADMIN_ROLE) {
        require(token != address(0), "MintEscrow: invalid token");
        stablecoin = MockUsdStable(token);
    }
    
    /**
     * @notice Set the country token address
     * @param token Address of CountryToken contract
     */
    function setCountryToken(address token) external onlyRole(ADMIN_ROLE){
        require(token != address(0), "MintEscrow: invalid token");
        countryToken = CountryToken(token);
    }
    

}

