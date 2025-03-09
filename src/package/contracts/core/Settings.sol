// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./_v0.1/ISettings.sol";
import "./_v0.1/IAccessManager.sol";

/**
 * @title Settings
 * @notice Manages global system settings
 * @dev Supports meta-transactions
 */
contract Settings is ISettings {
    // Access manager
    IAccessManager public immutable accessManager;
    
    // Default settings
    uint256 private _defaultMinProfitBps = 150; // 1.5%
    uint8 private _defaultFlashLoanProvider = 0; // AAVE
    uint256 private _gasPriceTarget = 1000000000; // 1 gwei
    bool private _emergencyStopActive = false;
    
    // Meta-transaction router
    address public metaTxRouter;
    
    // Events
    event DefaultMinProfitBpsUpdated(uint256 newValue);
    event DefaultFlashLoanProviderUpdated(uint8 newProvider);
    event GasPriceTargetUpdated(uint256 newTarget);
    event EmergencyStopUpdated(bool isActive);
    event MetaTxRouterUpdated(address indexed newRouter);
    
    /**
     * @notice Constructor
     * @param _accessManager Address of the access manager
     */
    constructor(address _accessManager) {
        accessManager = IAccessManager(_accessManager);
    }
    
    /**
     * @notice Set the meta-transaction router
     * @param _metaTxRouter Address of the meta-transaction router
     */
    function setMetaTxRouter(address _metaTxRouter) external override {
        require(accessManager.isAdmin(msg.sender), "Only admin");
        metaTxRouter = _metaTxRouter;
        emit MetaTxRouterUpdated(_metaTxRouter);
    }
    
    /**
     * @notice Get the sender for functions that support meta-transactions
     * @return The transaction sender (original signer for meta-transactions)
     */
    function _msgSender() internal view returns (address) {
        if (msg.sender == metaTxRouter) {
            // Extract signer from last 20 bytes of calldata
            return address(bytes20(msg.data[msg.data.length - 20:]));
        }
        return msg.sender;
    }
    
    /**
     * @notice Get the default minimum profit in basis points
     * @return The default minimum profit
     */
    function getDefaultMinProfitBps() external view override returns (uint256) {
        return _defaultMinProfitBps;
    }
    
    /**
     * @notice Get the default flash loan provider
     * @return The default provider index
     */
    function getDefaultFlashLoanProvider() external view override returns (uint8) {
        return _defaultFlashLoanProvider;
    }
    
    /**
     * @notice Get the gas price target in wei
     * @return The gas price target
     */
    function getGasPriceTarget() external view override returns (uint256) {
        return _gasPriceTarget;
    }
    
    /**
     * @notice Check if the emergency stop is active
     * @return True if emergency stop is active
     */
    function isEmergencyStopActive() external view override returns (bool) {
        return _emergencyStopActive;
    }
    
    /**
     * @notice Set the emergency stop status
     * @param isActive New active status
     */
    function setEmergencyStop(bool isActive) external override {
        require(accessManager.isAdmin(_msgSender()), "Only admin");
        _emergencyStopActive = isActive;
        emit EmergencyStopUpdated(isActive);
    }
    
    /**
     * @notice Set the default minimum profit
     * @param minProfitBps New minimum profit in basis points
     */
    function setDefaultMinProfitBps(uint256 minProfitBps) external override {
        require(accessManager.isAdmin(_msgSender()), "Only admin");
        require(minProfitBps <= 10000, "Value exceeds 100%");
        _defaultMinProfitBps = minProfitBps;
        emit DefaultMinProfitBpsUpdated(minProfitBps);
    }
    
    /**
     * @notice Set the default flash loan provider
     * @param provider The provider index
     */
    function setDefaultFlashLoanProvider(uint8 provider) external override {
        require(accessManager.isAdmin(_msgSender()), "Only admin");
        require(provider <= 3, "Invalid provider index"); // 0-3: AAVE, BALANCER, DODO, UNISWAP
        _defaultFlashLoanProvider = provider;
        emit DefaultFlashLoanProviderUpdated(provider);
    }
    
    /**
     * @notice Set the gas price target
     * @param target New gas price target in wei
     */
    function setGasPriceTarget(uint256 target) external override {
        require(accessManager.isAdmin(_msgSender()), "Only admin");
        _gasPriceTarget = target;
        emit GasPriceTargetUpdated(target);
    }
}
