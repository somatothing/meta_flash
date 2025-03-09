// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title IArbitrageController
 * @notice Main interface for controlling the arbitrage system
 */
interface IArbitrageController {
    /**
     * @notice Execute arbitrage with default parameters
     * @param pathId The ID of the path to execute
     * @return profit The profit made from arbitrage (0 if not profitable)
     */
    function executeArbitrage(uint256 pathId) external returns (uint256 profit);
    
    /**
     * @notice Execute arbitrage with custom parameters
     * @param pathId The ID of the path to execute
     * @param flashLoanProvider The flash loan provider to use
     * @param amount The amount to flash loan
     * @param minProfitBps Minimum profit in basis points
     * @return profit The profit made from arbitrage (0 if not profitable)
     */
    function executeArbitrageCustom(
        uint256 pathId,
        uint8 flashLoanProvider,
        uint256 amount,
        uint256 minProfitBps
    ) external returns (uint256 profit);
    
    /**
     * @notice Check if a path would be profitable
     * @param pathId The ID of the path to check
     * @return isProfitable Whether the path is profitable
     * @return expectedProfit The expected profit
     * @return profitBps The profit in basis points
     */
    function checkPathProfitability(
        uint256 pathId
    ) external view returns (bool isProfitable, uint256 expectedProfit, uint256 profitBps);
    
    /**
     * @notice Execute the most profitable path
     * @return profit The profit made from arbitrage
     */
    function executeBestArbitrage() external returns (uint256 profit);
    
    /**
     * @notice Execute a specific strategy
     * @param strategyId The ID of the strategy to execute
     * @return profit The profit made from arbitrage
     */
    function executeStrategy(uint256 strategyId) external returns (uint256 profit);
    
    /**
     * @notice Withdraw profits to a specified address
     * @param token Token address
     * @param to Address to send profits to
     * @param amount Amount to withdraw (0 for all)
     * @return The amount withdrawn
     */
    function withdrawProfits(address token, address to, uint256 amount) external returns (uint256);
    
    /**
     * @notice Set the meta-transaction router
     * @param _metaTxRouter Address of the meta-transaction router
     */
    function setMetaTxRouter(address _metaTxRouter) external;
}