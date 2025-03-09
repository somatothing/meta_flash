// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title IStrategyRegistry
 * @notice Interface for managing arbitrage strategies
 */
interface IStrategyRegistry {
    /**
     * @notice Strategy structure
     */
    struct Strategy {
        string name;
        uint256[] pathIds;
        uint8 flashLoanProvider;
        uint256 minProfitBps;
        bool isActive;
        uint256 gasLimit;
        uint256 executionInterval;
        uint256 lastExecutionTime;
    }
    
    /**
     * @notice Add a new strategy
     * @param name Strategy name
     * @param pathIds Array of path IDs to include
     * @param flashLoanProvider The flash loan provider to use
     * @param minProfitBps Minimum profit in basis points
     * @param gasLimit Gas limit for execution
     * @param executionInterval Minimum time between executions
     * @return strategyId The ID of the new strategy
     */
    function addStrategy(
        string calldata name,
        uint256[] calldata pathIds,
        uint8 flashLoanProvider,
        uint256 minProfitBps,
        uint256 gasLimit,
        uint256 executionInterval
    ) external returns (uint256 strategyId);
    
    /**
     * @notice Update strategy status
     * @param strategyId The ID of the strategy
     * @param isActive New active status
     */
    function setStrategyActive(uint256 strategyId, bool isActive) external;
    
    /**
     * @notice Get strategy details
     * @param strategyId The ID of the strategy
     * @return The strategy
     */
    function getStrategy(uint256 strategyId) external view returns (Strategy memory);
    
    /**
     * @notice Get strategy count
     * @return The number of strategies
     */
    function getStrategyCount() external view returns (uint256);
    
    /**
     * @notice Check if a strategy is ready for execution
     * @param strategyId The ID of the strategy
     * @return isReady Whether the strategy is ready
     */
    function isStrategyReady(uint256 strategyId) external view returns (bool isReady);
    
    /**
     * @notice Update last execution time for a strategy
     * @param strategyId The ID of the strategy
     * @param timestamp The execution timestamp
     */
    function updateLastExecutionTime(uint256 strategyId, uint256 timestamp) external;
    
    /**
     * @notice Set the meta-transaction router
     * @param _metaTxRouter Address of the meta-transaction router
     */
    function setMetaTxRouter(address _metaTxRouter) external;
}