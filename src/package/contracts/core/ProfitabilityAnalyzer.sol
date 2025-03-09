// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./_v0.1/IProfitabilityAnalyzer.sol";
import "./_v0.1/IAccessManager.sol";
import "./_v0.1/IPathRegistry.sol";
import "./_v0.1/IDEXAdapter.sol";
import "./_v0.1/IFlashLoanProvider.sol";
import "./_v0.1/ISettings.sol";
import "./_v0.1/IPriceOracle.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title ProfitabilityAnalyzer
 * @notice Analyzes arbitrage paths for profitability
 * @dev Simulates arbitrage execution to determine expected profit
 */
contract ProfitabilityAnalyzer is IProfitabilityAnalyzer {
    // Access manager
    IAccessManager public immutable accessManager;
    
    // Contract dependencies
    IPathRegistry public pathRegistry;
    IDEXAdapter public dexAdapter;
    IFlashLoanProvider public flashLoanProvider;
    ISettings public settings;
    IPriceOracle public priceOracle;
    
    // Constants
    uint256 public constant BASIS_POINTS = 10000;
    
    // Meta-transaction router
    address public metaTxRouter;
    
    // Events
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
    ) external {
        require(accessManager.isAdmin(msg.sender), "Only admin");
        pathRegistry = IPathRegistry(_pathRegistry);
        dexAdapter = IDEXAdapter(_dexAdapter);
        flashLoanProvider = IFlashLoanProvider(_flashLoanProvider);
        settings = ISettings(_settings);
        priceOracle = IPriceOracle(_priceOracle);
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
    ) external view override returns (bool isProfitable, uint256 expectedProfit, uint256 profitBps) {
        // Get path info
        IPathRegistry.ArbitragePath memory path = pathRegistry.getPath(pathId);
        require(path.isActive, "Path is not active");
        require(amount <= path.maxAmount, "Amount exceeds path maximum");
        
        // Get loan fee
        uint256 flashLoanFeeBps = flashLoanProvider.getFlashLoanFeeBps(
            IFlashLoanProvider.Protocol(flashLoanProvider),
            path.tokens[0],
            amount
        );
        
        // Calculate repayment amount
        uint256 repayAmount = amount + (amount * flashLoanFeeBps / BASIS_POINTS);
        
        // Simulate arbitrage swaps
        uint256 finalAmount = _simulateArbitrageSwaps(path, amount);
        
        // Check if profitable
        if (finalAmount > repayAmount) {
            expectedProfit = finalAmount - repayAmount;
            profitBps = (expectedProfit * BASIS_POINTS) / amount;
            isProfitable = profitBps >= settings.getDefaultMinProfitBps();
        } else {
            expectedProfit = 0;
            profitBps = 0;
            isProfitable = false;
        }
        
        return (isProfitable, expectedProfit, profitBps);
    }
    
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
    ) external view override returns (uint256 optimalAmount, uint256 expectedProfit) {
        // Get path info
        IPathRegistry.ArbitragePath memory path = pathRegistry.getPath(pathId);
        require(path.isActive, "Path is not active");
        
        // Get max loan size
        uint256 maxLoanSize = flashLoanProvider.getMaxLoanSize(
            IFlashLoanProvider.Protocol(flashLoanProvider),
            path.tokens[0]
        );
        
        // Cap by path maximum
        maxLoanSize = maxLoanSize > path.maxAmount ? path.maxAmount : maxLoanSize;
        
        // Binary search for optimal amount
        uint256 minAmount = 1000; // Minimum viable amount (e.g., 1000 wei)
        uint256 maxAmount = maxLoanSize;
        uint256 bestProfit = 0;
        optimalAmount = 0;
        
        // Starting test points
        uint256[] memory testPoints = new uint256[](5);
        testPoints[0] = minAmount;
        testPoints[1] = minAmount + (maxAmount - minAmount) / 4;
        testPoints[2] = minAmount + (maxAmount - minAmount) / 2;
        testPoints[3] = minAmount + (maxAmount - minAmount) * 3 / 4;
        testPoints[4] = maxAmount;
        
        // Test each point
        for (uint256 i = 0; i < testPoints.length; i++) {
            (bool isProfitable, uint256 profit, ) = this.checkPathProfitability(
                pathId,
                flashLoanProvider,
                testPoints[i]
            );
            
            if (isProfitable && profit > bestProfit) {
                bestProfit = profit;
                optimalAmount = testPoints[i];
            }
        }
        
        // Fine-tune around the best point if found
        if (optimalAmount > 0) {
            uint256 lower = optimalAmount * 90 / 100; // 90% of optimal
            uint256 higher = optimalAmount * 110 / 100; // 110% of optimal
            higher = higher > maxAmount ? maxAmount : higher;
            
            // Test lower
            (bool isProfitableLower, uint256 profitLower, ) = this.checkPathProfitability(
                pathId,
                flashLoanProvider,
                lower
            );
            
            if (isProfitableLower && profitLower > bestProfit) {
                bestProfit = profitLower;
                optimalAmount = lower;
            }
            
            // Test higher
            (bool isProfitableHigher, uint256 profitHigher, ) = this.checkPathProfitability(
                pathId,
                flashLoanProvider,
                higher
            );
            
            if (isProfitableHigher && profitHigher > bestProfit) {
                bestProfit = profitHigher;
                optimalAmount = higher;
            }
        }
        
        expectedProfit = bestProfit;
        return (optimalAmount, expectedProfit);
    }
    
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
    ) external view override returns (
        uint256 pathId,
        uint8 flashLoanProvider,
        uint256 optimalAmount,
        uint256 expectedProfit
    ) {
        uint256[] memory pathIds;
        
        // Get paths based on category
        if (category == 0) {
            // Get all paths
            uint256 pathCount = pathRegistry.getPathCount();
            pathIds = new uint256[](pathCount);
            for (uint256 i = 0; i < pathCount; i++) {
                pathIds[i] = i;
            }
        } else {
            // Get paths for specific category
            pathIds = pathRegistry.getPathsByCategory(category);
        }
        
        // Check each path with each flash loan provider
        uint256 bestProfit = 0;
        uint8 bestProvider = 0;
        uint256 bestPathId = 0;
        uint256 bestAmount = 0;
        
        // Loop through paths
        for (uint256 i = 0; i < pathIds.length; i++) {
            IPathRegistry.ArbitragePath memory path = pathRegistry.getPath(pathIds[i]);
            if (!path.isActive) continue;
            
            // Loop through providers
            for (uint8 j = 0; j < 4; j++) { // 4 protocols: AAVE, BALANCER, DODO, UNISWAP
                // Get optimal amount for this path and provider
                (uint256 amount, uint256 profit) = this.getOptimalAmount(pathIds[i], j);
                
                if (profit > bestProfit) {
                    bestProfit = profit;
                    bestProvider = j;
                    bestPathId = pathIds[i];
                    bestAmount = amount;
                }
            }
        }
        
        return (bestPathId, bestProvider, bestAmount, bestProfit);
    }
    
    /**
     * @notice Simulate arbitrage swaps to determine expected outcome
     * @param path The arbitrage path
     * @param amount The initial amount
     * @return finalAmount The final amount after swaps
     */
    function _simulateArbitrageSwaps(
        IPathRegistry.ArbitragePath memory path,
        uint256 amount
    ) internal view returns (uint256 finalAmount) {
        uint256 currentAmount = amount;
        
        // Simulate each swap in the path
        for (uint256 i = 0; i < path.tokens.length - 1; i++) {
            address tokenIn = path.tokens[i];
            address tokenOut = path.tokens[i + 1];
            uint24 poolFee = path.poolFees[i];
            
            // Get quote for this swap
            uint256 amountOut = dexAdapter.getQuote(
                IDEXAdapter.DEX(path.dexes[i]),
                tokenIn,
                tokenOut,
                currentAmount,
                poolFee
            );
            
            // If any swap fails, the whole arbitrage fails
            if (amountOut == 0) {
                return 0;
            }
            
            // Update current amount for next swap
            currentAmount = amountOut;
        }
        
        return currentAmount;
    }
}
