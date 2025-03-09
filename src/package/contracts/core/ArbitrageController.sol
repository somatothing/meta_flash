// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./_v0.1/IArbitrageController.sol";
import "./_v0.1/IAccessManager.sol";
import "./_v0.1/IPathRegistry.sol";
import "./_v0.1/IFlashLoanProvider.sol";
import "./_v0.1/IProfitabilityAnalyzer.sol";
import "./_v0.1/ISettings.sol";
import "./_v0.1/IStrategyRegistry.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ArbitrageController
 * @notice Main controller for the arbitrage system
 * @dev Coordinates flash loans, path execution, and profitability checks
 */
contract ArbitrageController is IArbitrageController {
    // Access manager
    IAccessManager public immutable accessManager;
    
    // Contract dependencies
    IPathRegistry public pathRegistry;
    IFlashLoanProvider public flashLoanProvider;
    IProfitabilityAnalyzer public profitabilityAnalyzer;
    ISettings public settings;
    IStrategyRegistry public strategyRegistry;
    
    // Meta-transaction router
    address public metaTxRouter;
    
    // Events
    event ArbitrageExecuted(uint256 indexed pathId, uint8 flashLoanProvider, uint256 amount, uint256 profit, bool success);
    event ArbitrageAttemptFailed(uint256 indexed pathId, uint8 flashLoanProvider, uint256 amount, string reason);
    event StrategyExecuted(uint256 indexed strategyId, uint256 pathId, uint256 profit);
    event MetaTxRouterUpdated(address indexed newRouter);
    
    /**
     * @notice Constructor
     * @param _accessManager Access manager address
     */
    constructor(address _accessManager) {
        accessManager = IAccessManager(_accessManager);
    }
    
    /**
     * @notice Set contract dependencies
     * @param _pathRegistry Path registry address
     * @param _flashLoanProvider Flash loan provider address
     * @param _profitabilityAnalyzer Profitability analyzer address
     * @param _settings Settings address
     * @param _strategyRegistry Strategy registry address
     */
    function setDependencies(
        address _pathRegistry,
        address _flashLoanProvider,
        address _profitabilityAnalyzer,
        address _settings,
        address _strategyRegistry
    ) external {
        require(accessManager.isAdmin(msg.sender), "Only admin");
        pathRegistry = IPathRegistry(_pathRegistry);
        flashLoanProvider = IFlashLoanProvider(_flashLoanProvider);
        profitabilityAnalyzer = IProfitabilityAnalyzer(_profitabilityAnalyzer);
        settings = ISettings(_settings);
        strategyRegistry = IStrategyRegistry(_strategyRegistry);
    }
    
    /**
     * @notice Set the meta-transaction router
     * @param _metaTxRouter Address of the meta-transaction router
     */
    function setMetaTxRouter(address _metaTxRouter) external {
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
     * @notice Modifier for operator access
     */
    modifier onlyOperator() {
        require(accessManager.isOperator(_msgSender()), "Only operator");
        _;
    }
    
    /**
     * @notice Check emergency stop
     */
    modifier whenNotStopped() {
        require(!settings.isEmergencyStopActive(), "Emergency stop active");
        _;
    }
    
    /**
     * @notice Execute arbitrage with default parameters
     * @param pathId The ID of the path to execute
     * @return profit The profit made from arbitrage (0 if not profitable)
     */
    function executeArbitrage(uint256 pathId) external override onlyOperator whenNotStopped returns (uint256 profit) {
        // Get path info
        IPathRegistry.ArbitragePath memory path = pathRegistry.getPath(pathId);
        require(path.isActive, "Path is not active");
        
        // Get default settings
        uint8 defaultProvider = settings.getDefaultFlashLoanProvider();
        uint256 minProfitBps = settings.getDefaultMinProfitBps();
        
        // Find optimal amount
        (uint256 optimalAmount, uint256 expectedProfit) = profitabilityAnalyzer.getOptimalAmount(
            pathId,
            defaultProvider
        );
        
        // Check if profitable
        if (optimalAmount == 0 || expectedProfit == 0) {
            emit ArbitrageAttemptFailed(pathId, defaultProvider, 0, "Not profitable");
            return 0;
        }
        
        // Execute with optimal amount
        return executeArbitrageCustom(pathId, defaultProvider, optimalAmount, minProfitBps);
    }
    
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
    ) public override onlyOperator whenNotStopped returns (uint256 profit) {
        // Get path info
        IPathRegistry.ArbitragePath memory path = pathRegistry.getPath(pathId);
        require(path.isActive, "Path is not active");
        require(amount <= path.maxAmount, "Amount exceeds path maximum");
        
        // Check profitability
        (bool isProfitable, uint256 expectedProfit, ) = profitabilityAnalyzer.checkPathProfitability(
            pathId,
            flashLoanProvider,
            amount
        );
        
        if (!isProfitable) {
            emit ArbitrageAttemptFailed(pathId, flashLoanProvider, amount, "Not profitable");
            return 0;
        }
        
        try flashLoanProvider.executeFlashLoan(
            IFlashLoanProvider.Protocol(flashLoanProvider),
            path.tokens[0],
            amount,
            pathId,
            minProfitBps
        ) returns (uint256 actualProfit) {
            // Success
            emit ArbitrageExecuted(pathId, flashLoanProvider, amount, actualProfit, true);
            return actualProfit;
        } catch Error(string memory reason) {
            emit ArbitrageAttemptFailed(pathId, flashLoanProvider, amount, reason);
            return 0;
        } catch {
            emit ArbitrageAttemptFailed(pathId, flashLoanProvider, amount, "Unknown error");
            return 0;
        }
    }
    
    /**
     * @notice Check if a path would be profitable
     * @param pathId The ID of the path to check
     * @return isProfitable Whether the path is profitable
     * @return expectedProfit The expected profit
     * @return profitBps The profit in basis points
     */
    function checkPathProfitability(
        uint256 pathId
    ) external view override returns (bool isProfitable, uint256 expectedProfit, uint256 profitBps) {
        // Get default flash loan provider
        uint8 defaultProvider = settings.getDefaultFlashLoanProvider();
        
        // Find optimal amount
        (uint256 optimalAmount, ) = profitabilityAnalyzer.getOptimalAmount(
            pathId,
            defaultProvider
        );
        
        if (optimalAmount == 0) {
            return (false, 0, 0);
        }
        
        // Check profitability with optimal amount
        return profitabilityAnalyzer.checkPathProfitability(
            pathId,
            defaultProvider,
            optimalAmount
        );
    }
    
    /**
     * @notice Execute a strategy
     * @param strategyId The ID of the strategy to execute
     * @return profit The profit made from the strategy
     */
    function executeStrategy(uint256 strategyId) external onlyOperator whenNotStopped returns (uint256 profit) {
        // Get strategy
        IStrategyRegistry.Strategy memory strategy = strategyRegistry.getStrategy(strategyId);
        require(strategy.isActive, "Strategy is not active");
        
        // Check if it's time to execute
        require(strategyRegistry.isStrategyReady(strategyId), "Strategy not ready");
        
        // Find most profitable path in the strategy
        uint256 bestPathId = 0;
        uint256 bestProfit = 0;
        
        for (uint256 i = 0; i < strategy.pathIds.length; i++) {
            (bool isProfitable, uint256 expectedProfit, ) = profitabilityAnalyzer.checkPathProfitability(
                strategy.pathIds[i],
                strategy.flashLoanProvider,
                0 // Let the analyzer find the optimal amount
            );
            
            if (isProfitable && expectedProfit > bestProfit) {
                bestProfit = expectedProfit;
                bestPathId = strategy.pathIds[i];
            }
        }
        
        if (bestPathId == 0 || bestProfit == 0) {
            emit ArbitrageAttemptFailed(0, strategy.flashLoanProvider, 0, "No profitable paths in strategy");
            return 0;
        }
        
        // Execute the best path
        uint256 actualProfit = executeArbitrageCustom(
            bestPathId,
            strategy.flashLoanProvider,
            0, // Let the controller find the optimal amount
            strategy.minProfitBps
        );
        
        if (actualProfit > 0) {
            // Update strategy execution time
            strategyRegistry.updateLastExecutionTime(strategyId, block.timestamp);
            emit StrategyExecuted(strategyId, bestPathId, actualProfit);
        }
        
        return actualProfit;
    }
    
    /**
     * @notice Execute the most profitable path across all categories
     * @return profit The profit made
     */
    function executeBestArbitrage() external onlyOperator whenNotStopped returns (uint256 profit) {
        // Find most profitable path
        (
            uint256 pathId,
            uint8 provider,
            uint256 amount,
            uint256 expectedProfit
        ) = profitabilityAnalyzer.findMostProfitablePath(0); // 0 = all categories
        
        if (pathId == 0 || amount == 0 || expectedProfit == 0) {
            emit ArbitrageAttemptFailed(0, 0, 0, "No profitable paths found");
            return 0;
        }
        
        // Execute with found parameters
        return executeArbitrageCustom(
            pathId,
            provider,
            amount,
            settings.getDefaultMinProfitBps()
        );
    }
    
    /**
     * @notice Withdraw profits to a specified address
     * @param token Token address
     * @param to Address to send profits to
     * @param amount Amount to withdraw (0 for all)
     * @return The amount withdrawn
     */
    function withdrawProfits(address token, address to, uint256 amount) external onlyOperator returns (uint256) {
        require(to != address(0), "Invalid recipient");
        
        uint256 balance = IERC20(token).balanceOf(address(this));
        uint256 withdrawAmount = amount == 0 ? balance : amount;
        
        require(withdrawAmount <= balance, "Insufficient balance");
        
        if (withdrawAmount > 0) {
            IERC20(token).transfer(to, withdrawAmount);
        }
        
        return withdrawAmount;
    }
}
