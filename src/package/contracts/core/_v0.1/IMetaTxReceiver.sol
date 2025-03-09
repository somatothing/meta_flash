// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title IMetaTxReceiver
 * @notice Interface for contracts that can receive meta-transactions
 */
interface IMetaTxReceiver {
    /**
     * @notice MetaTransaction request structure
     */
    struct MetaTxRequest {
        address signer;
        address target;
        bytes data;
        uint256 nonce;
        uint256 deadline;
        bytes signature;
    }
    
    /**
     * @notice Execute a meta-transaction
     * @param req The meta-transaction request
     * @return result The return data from the called function
     */
    function executeMetaTransaction(MetaTxRequest calldata req) external returns (bytes memory result);
    
    /**
     * @notice Get the current nonce for a signer
     * @param signer The address to get nonce for
     * @return The current nonce
     */
    function getNonce(address signer) external view returns (uint256);
}

/**
 * @title IAccessManager
 * @notice Interface for access control management
 */
interface IAccessManager {
    /**
     * @notice Check if an account is an admin
     * @param account The account to check
     * @return True if the account is an admin
     */
    function isAdmin(address account) external view returns (bool);
    
    /**
     * @notice Check if an account is an operator
     * @param account The account to check
     * @return True if the account is an operator
     */
    function isOperator(address account) external view returns (bool);
    
    /**
     * @notice Grant admin role to an account
     * @param account The account to grant admin to
     */
    function grantAdmin(address account) external;
    
    /**
     * @notice Revoke admin role from an account
     * @param account The account to revoke admin from
     */
    function revokeAdmin(address account) external;
    
    /**
     * @notice Grant operator role to an account
     * @param account The account to grant operator to
     */
    function grantOperator(address account) external;
    
    /**
     * @notice Revoke operator role from an account
     * @param account The account to revoke operator from
     */
    function revokeOperator(address account) external;
}

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
}

/**
 * @title IArbitrageExecutor
 * @notice Interface for executing arbitrage operations
 */
interface IArbitrageExecutor {
    /**
     * @notice Execute a series of swaps for arbitrage
     * @param flashLoanProvider The flash loan provider to use
     * @param token The token to flash loan
     * @param amount The amount to flash loan
     * @param path The path to execute
     * @param minProfitBps Minimum profit in basis points
     * @return profit The profit made from arbitrage (0 if not profitable)
     */
    function executeArbitragePath(
        uint8 flashLoanProvider,
        address token,
        uint256 amount,
        uint256 pathId,
        uint256 minProfitBps
    ) external returns (uint256 profit);
}

/**
 * @title IFlashLoanProvider
 * @notice Interface for flash loan providers
 */
interface IFlashLoanProvider {
    /**
     * @notice Available flash loan protocols
     */
    enum Protocol { AAVE, BALANCER, DODO, UNISWAP }
    
    /**
     * @notice Flash loan callback data structure
     */
    struct FlashLoanCallbackData {
        Protocol protocol;
        address initiator;
        address token;
        uint256 amount;
        uint256 fee;
        uint256 pathId;
        uint256 minProfitBps;
    }
    
    /**
     * @notice Execute a flash loan
     * @param protocol The protocol to use
     * @param token The token to borrow
     * @param amount The amount to borrow
     * @param pathId The ID of the path to execute
     * @param minProfitBps Minimum profit in basis points
     * @return profit The profit from the flash loan
     */
    function executeFlashLoan(
        Protocol protocol,
        address token,
        uint256 amount,
        uint256 pathId,
        uint256 minProfitBps
    ) external returns (uint256 profit);
    
    /**
     * @notice Get the flash loan fee for a protocol
     * @param protocol The protocol to check
     * @param token The token to check
     * @param amount The amount to check
     * @return The fee in basis points
     */
    function getFlashLoanFeeBps(
        Protocol protocol,
        address token,
        uint256 amount
    ) external view returns (uint256);
    
    /**
     * @notice Get maximum loan size for a token on a protocol
     * @param protocol The protocol to check
     * @param token The token to check
     * @return The maximum loan size
     */
    function getMaxLoanSize(
        Protocol protocol,
        address token
    ) external view returns (uint256);
}

/**
 * @title IPathRegistry
 * @notice Interface for managing arbitrage paths
 */
interface IPathRegistry {
    /**
     * @notice Arbitrage path structure
     */
    struct ArbitragePath {
        address[] tokens;
        uint8[] dexes;
        uint24[] poolFees;
        bool isActive;
        uint256 maxAmount;
        string name;
        uint8 category;
    }
    
    /**
     * @notice Add a new arbitrage path
     * @param tokens Array of token addresses in the path
     * @param dexes Array of DEX indices for each swap
     * @param poolFees Array of pool fees for each swap
     * @param maxAmount Maximum amount for the path
     * @param name Human-readable name for the path
     * @param category Category index for the path
     * @return pathId The ID of the new path
     */
    function addPath(
        address[] calldata tokens,
        uint8[] calldata dexes,
        uint24[] calldata poolFees,
        uint256 maxAmount,
        string calldata name,
        uint8 category
    ) external returns (uint256 pathId);
    
    /**
     * @notice Update path status
     * @param pathId The ID of the path
     * @param isActive New active status
     */
    function setPathActive(uint256 pathId, bool isActive) external;
    
    /**
     * @notice Get path details
     * @param pathId The ID of the path
     * @return path The arbitrage path
     */
    function getPath(uint256 pathId) external view returns (ArbitragePath memory path);
    
    /**
     * @notice Get path count
     * @return The number of paths
     */
    function getPathCount() external view returns (uint256);
    
    /**
     * @notice Get paths by category
     * @param category The category to filter by
     * @return pathIds Array of path IDs
     */
    function getPathsByCategory(uint8 category) external view returns (uint256[] memory pathIds);
}

/**
 * @title IDEXAdapter
 * @notice Interface for DEX adapters
 */
interface IDEXAdapter {
    /**
     * @notice Available DEXes
     */
    enum DEX { UNISWAP, SUSHISWAP, CAMELOT, BALANCER }
    
    /**
     * @notice Execute a swap
     * @param dex The DEX to use
     * @param tokenIn The input token
     * @param tokenOut The output token
     * @param amountIn The input amount
     * @param poolFee The pool fee (if applicable)
     * @param recipient The recipient of the output tokens
     * @return amountOut The output amount
     */
    function swap(
        DEX dex,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint24 poolFee,
        address recipient
    ) external returns (uint256 amountOut);
    
    /**
     * @notice Get a quote for a swap
     * @param dex The DEX to check
     * @param tokenIn The input token
     * @param tokenOut The output token
     * @param amountIn The input amount
     * @param poolFee The pool fee (if applicable)
     * @return amountOut The expected output amount
     */
    function getQuote(
        DEX dex,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint24 poolFee
    ) external view returns (uint256 amountOut);
}

/**
 * @title IPriceOracle
 * @notice Interface for price oracles
 */
interface IPriceOracle {
    /**
     * @notice Get token price in USD
     * @param token The token to check
     * @return The price in USD (scaled by 10^18)
     */
    function getTokenPriceUSD(address token) external view returns (uint256);
    
    /**
     * @notice Get relative price between tokens
     * @param tokenA The base token
     * @param tokenB The quote token
     * @return The price of tokenA in tokenB (scaled by 10^18)
     */
    function getRelativePrice(address tokenA, address tokenB) external view returns (uint256);
    
    /**
     * @notice Get the best DEX for a swap
     * @param tokenIn The input token
     * @param tokenOut The output token
     * @param amountIn The input amount
     * @return bestDex The best DEX index
     * @return bestFee The best pool fee 
     * @return amountOut The expected output amount
     */
    function getBestDexForSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint8 bestDex, uint24 bestFee, uint256 amountOut);
}

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
}

/**
 * @title IPoolAnalyzer
 * @notice Interface for analyzing liquidity pools
 */
interface IPoolAnalyzer {
    /**
     * @notice Get pool information
     * @param dex The DEX index
     * @param tokenA The first token
     * @param tokenB The second token
     * @param fee The pool fee
     * @return liquidity The pool liquidity
     * @return tokenAReserve The reserve of tokenA
     * @return tokenBReserve The reserve of tokenB
     * @return maxSwapAmount The maximum swap amount
     */
    function getPoolInfo(
        uint8 dex,
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view returns (
        uint256 liquidity,
        uint256 tokenAReserve,
        uint256 tokenBReserve,
        uint256 maxSwapAmount
    );
    
    /**
     * @notice Calculate price impact for a swap
     * @param dex The DEX index
     * @param tokenIn The input token
     * @param tokenOut The output token
     * @param amountIn The input amount
     * @param fee The pool fee
     * @return priceImpactBps The price impact in basis points
     */
    function calculatePriceImpact(
        uint8 dex,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint24 fee
    ) external view returns (uint256 priceImpactBps);
}

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
}

/**
 * @title ILiquidityRegistry
 * @notice Interface for tracking liquidity information
 */
interface ILiquidityRegistry {
    /**
     * @notice Update liquidity data for a pool
     * @param dex The DEX index
     * @param tokenA The first token
     * @param tokenB The second token
     * @param fee The pool fee
     * @param liquidity The pool liquidity
     * @param tokenAReserve The reserve of tokenA
     * @param tokenBReserve The reserve of tokenB
     */
    function updatePoolData(
        uint8 dex,
        address tokenA,
        address tokenB,
        uint24 fee,
        uint256 liquidity,
        uint256 tokenAReserve,
        uint256 tokenBReserve
    ) external;
    
    /**
     * @notice Get pool hash for efficient lookups
     * @param dex The DEX index
     * @param tokenA The first token
     * @param tokenB The second token
     * @param fee The pool fee
     * @return The hash representing the pool
     */
    function getPoolHash(
        uint8 dex,
        address tokenA,
        address tokenB,
        uint24 fee
    ) external pure returns (bytes32);
    
    /**
     * @notice Get liquidity data for a pool
     * @param poolHash The pool hash
     * @return liquidity The pool liquidity
     * @return tokenAReserve The reserve of tokenA
     * @return tokenBReserve The reserve of tokenB
     * @return lastUpdateTimestamp Last update timestamp
     */
    function getPoolData(bytes32 poolHash) external view returns (
        uint256 liquidity,
        uint256 tokenAReserve,
        uint256 tokenBReserve,
        uint256 lastUpdateTimestamp
    );
}

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
}