// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title IProfitabilityAnalyzer
 * @notice Interface for analyzing path profitability
 */
interface IProfitabilityAnalyzer {
    /**
     * @notice Check if a path is profitable
     * @param pathId The ID of the path to check
     * @param flashLoanProvider The flash loan provider to use
     * @param amount The amount to flash loan
     * @return isProfitable Whether the path is profitable
     * @return expectedProfit The expected profit
     * @return profitBps The profit in basis points
     */
    function checkPathProfitability(
        uint256 pathId,
        uint8 flashLoanProvider,
        uint256 amount
    ) external view returns (bool isProfitable, uint256 expectedProfit, uint256 profitBps);
    
    /**
     * @notice Get the optimal amount for maximum profit
     * @param pathId The ID of the path
     * @param flashLoanProvider The flash loan provider
     * @return optimalAmount The amount for maximum profit
     * @return expectedProfit The expected profit
     */
    function getOptimalAmount(
        uint256 pathId,
        uint8 flashLoanProvider
    ) external view returns (uint256 optimalAmount, uint256 expectedProfit);
    
    /**
     * @notice Find the most profitable path
     * @param category The category to filter by (0 for all)
     * @return pathId The most profitable path ID
     * @return flashLoanProvider The best flash loan provider
     * @return optimalAmount The optimal amount
     * @return expectedProfit The expected profit
     */
    function findMostProfitablePath(
        uint8 category
    ) external view returns (
        uint256 pathId,
        uint8 flashLoanProvider,
        uint256 optimalAmount,
        uint256 expectedProfit
    );
    
    /**
     * @notice Set contract dependencies
     * @param _pathRegistry Path registry address
     * @param _dexAdapter DEX adapter address
     * @param _flashLoanProvider Flash loan provider address
     * @param _settings Settings address
     * @param _priceOracle Price oracle address
     */
    function setDependencies(
        address _pathRegistry,
        address _dexAdapter,
        address _flashLoanProvider,
        address _settings,
        address _priceOracle
    ) external;
    
    /**
     * @notice Set the meta-transaction router
     * @param _metaTxRouter Address of the meta-transaction router
     */
    function setMetaTxRouter(address _metaTxRouter) external;
}