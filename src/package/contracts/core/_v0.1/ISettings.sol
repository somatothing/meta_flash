// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title ISettings
 * @notice Interface for global system settings
 */
interface ISettings {
    /**
     * @notice Get the default minimum profit in basis points
     * @return The default minimum profit
     */
    function getDefaultMinProfitBps() external view returns (uint256);
    
    /**
     * @notice Get the default flash loan provider
     * @return The default provider index
     */
    function getDefaultFlashLoanProvider() external view returns (uint8);
    
    /**
     * @notice Get the gas price target in wei
     * @return The gas price target
     */
    function getGasPriceTarget() external view returns (uint256);
    
    /**
     * @notice Check if the emergency stop is active
     * @return True if emergency stop is active
     */
    function isEmergencyStopActive() external view returns (bool);
    
    /**
     * @notice Set the emergency stop status
     * @param isActive New active status
     */
    function setEmergencyStop(bool isActive) external;
    
    /**
     * @notice Set the default minimum profit
     * @param minProfitBps New minimum profit in basis points
     */
    function setDefaultMinProfitBps(uint256 minProfitBps) external;
    
    /**
     * @notice Set the default flash loan provider
     * @param provider The provider index
     */
    function setDefaultFlashLoanProvider(uint8 provider) external;
    
    /**
     * @notice Set the gas price target
     * @param target New gas price target in wei
     */
    function setGasPriceTarget(uint256 target) external;
    
    /**
     * @notice Set the meta-transaction router
     * @param _metaTxRouter Address of the meta-transaction router
     */
    function setMetaTxRouter(address _metaTxRouter) external;
}