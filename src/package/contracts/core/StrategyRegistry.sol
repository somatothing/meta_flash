// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./_v0.1/IStrategyRegistry.sol";
import "./_v0.1/IAccessManager.sol";

/**
 * @title StrategyRegistry
 * @notice Manages arbitrage strategies
 * @dev Supports meta-transactions
 */
contract StrategyRegistry is IStrategyRegistry {
    // Access manager
    IAccessManager public immutable accessManager;
    
    // Meta-transaction router
    address public metaTxRouter;
    
    // Strategies storage
    Strategy[] private _strategies;
    
    // ArbitrageController address (authorized to update execution times)
    address public arbitrageController;
    
    // Events
    event StrategyAdded(uint256 indexed strategyId, string name, uint256[] pathIds);
    event StrategyUpdated(uint256 indexed strategyId, bool isActive);
    event StrategyExecuted(uint256 indexed strategyId, uint256 timestamp);
    event ArbitrageControllerUpdated(address indexed controller);
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
     * @notice Set the arbitrage controller address
     * @param _arbitrageController Address of the arbitrage controller
     */
    function setArbitrageController(address _arbitrageController) external {
        require(accessManager.isAdmin(msg.sender), "Only admin");
        arbitrageController = _arbitrageController;
        emit ArbitrageControllerUpdated(_arbitrageController);
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
     * @notice Modifier for controller access
     */
    modifier onlyController() {
        require(
            msg.sender == arbitrageController || 
            accessManager.isAdmin(msg.sender), 
            "Only controller or admin"
        );
        _;
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
    ) external override onlyOperator returns (uint256 strategyId) {
        require(pathIds.length > 0, "No paths provided");
        require(flashLoanProvider <= 3, "Invalid provider index"); // 0-3: AAVE, BALANCER, DODO, UNISWAP
        require(minProfitBps > 0, "Min profit must be > 0");
        require(executionInterval > 0, "Execution interval must be > 0");
        
        // Create new strategy
        _strategies.push(Strategy({
            name: name,
            pathIds: pathIds,
            flashLoanProvider: flashLoanProvider,
            minProfitBps: minProfitBps,
            isActive: true,
            gasLimit: gasLimit,
            executionInterval: executionInterval,
            lastExecutionTime: 0
        }));
        
        strategyId = _strategies.length - 1;
        
        emit StrategyAdded(strategyId, name, pathIds);
        
        return strategyId;
    }
    
    /**
     * @notice Update strategy status
     * @param strategyId The ID of the strategy
     * @param isActive New active status
     */
    function setStrategyActive(uint256 strategyId, bool isActive) external override onlyOperator {
        require(strategyId < _strategies.length, "Invalid strategy ID");
        
        _strategies[strategyId].isActive = isActive;
        
        emit StrategyUpdated(strategyId, isActive);
    }
    
    /**
     * @notice Get strategy details
     * @param strategyId The ID of the strategy
     * @return The strategy
     */
    function getStrategy(uint256 strategyId) external view override returns (Strategy memory) {
        require(strategyId < _strategies.length, "Invalid strategy ID");
        return _strategies[strategyId];
    }
    
    /**
     * @notice Get strategy count
     * @return The number of strategies
     */
    function getStrategyCount() external view override returns (uint256) {
        return _strategies.length;
    }
    
    /**
     * @notice Check if a strategy is ready for execution
     * @param strategyId The ID of the strategy
     * @return isReady Whether the strategy is ready
     */
    function isStrategyReady(uint256 strategyId) external view override returns (bool isReady) {
        require(strategyId < _strategies.length, "Invalid strategy ID");
        
        Strategy storage strategy = _strategies[strategyId];
        
        // Strategy must be active
        if (!strategy.isActive) {
            return false;
        }
        
        // Check if enough time has passed since last execution
        if (strategy.lastExecutionTime == 0) {
            // Never executed before
            return true;
        } else {
            return block.timestamp >= strategy.lastExecutionTime + strategy.executionInterval;
        }
    }
    
    /**
     * @notice Update last execution time for a strategy
     * @param strategyId The ID of the strategy
     * @param timestamp The execution timestamp
     */
    function updateLastExecutionTime(uint256 strategyId, uint256 timestamp) external override onlyController {
        require(strategyId < _strategies.length, "Invalid strategy ID");
        
        _strategies[strategyId].lastExecutionTime = timestamp;
        
        emit StrategyExecuted(strategyId, timestamp);
    }
    
    /**
     * @notice Update strategy parameters
     * @param strategyId The ID of the strategy
     * @param minProfitBps New minimum profit in basis points
     * @param gasLimit New gas limit
     * @param executionInterval New execution interval
     */
    function updateStrategyParams(
        uint256 strategyId,
        uint256 minProfitBps,
        uint256 gasLimit,
        uint256 executionInterval
    ) external onlyOperator {
        require(strategyId < _strategies.length, "Invalid strategy ID");
        require(minProfitBps > 0, "Min profit must be > 0");
        require(executionInterval > 0, "Execution interval must be > 0");
        
        Strategy storage strategy = _strategies[strategyId];
        
        strategy.minProfitBps = minProfitBps;
        strategy.gasLimit = gasLimit;
        strategy.executionInterval = executionInterval;
    }
    
    /**
     * @notice Update strategy paths
     * @param strategyId The ID of the strategy
     * @param pathIds New path IDs
     */
    function updateStrategyPaths(
        uint256 strategyId,
        uint256[] calldata pathIds
    ) external onlyOperator {
        require(strategyId < _strategies.length, "Invalid strategy ID");
        require(pathIds.length > 0, "No paths provided");
        
        _strategies[strategyId].pathIds = pathIds;
    }
    
    /**
     * @notice Update strategy flash loan provider
     * @param strategyId The ID of the strategy
     * @param flashLoanProvider New flash loan provider
     */
    function updateStrategyProvider(
        uint256 strategyId,
        uint8 flashLoanProvider
    ) external onlyOperator {
        require(strategyId < _strategies.length, "Invalid strategy ID");
        require(flashLoanProvider <= 3, "Invalid provider index");
        
        _strategies[strategyId].flashLoanProvider = flashLoanProvider;
    }
}
