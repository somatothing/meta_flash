// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./_v0.1/ILiquidityRegistry.sol";
import "./_v0.1/IAccessManager.sol";

/**
 * @title LiquidityRegistry
 * @notice Manages and tracks liquidity information for various pools
 * @dev Supports meta-transactions
 */
contract LiquidityRegistry is ILiquidityRegistry {
    // Access manager
    IAccessManager public immutable accessManager;
    
    // Meta-transaction router
    address public metaTxRouter;
    
    // Pool data structure
    struct PoolData {
        uint256 liquidity;
        uint256 tokenAReserve;
        uint256 tokenBReserve;
        uint256 lastUpdateTimestamp;
        bool exists;
    }
    
    // Mapping from pool hash to pool data
    mapping(bytes32 => PoolData) private _poolData;
    
    // List of all pool hashes
    bytes32[] private _poolHashes;
    
    // Events
    event PoolDataUpdated(
        bytes32 indexed poolHash,
        uint8 dex,
        address tokenA,
        address tokenB,
        uint24 fee,
        uint256 liquidity,
        uint256 tokenAReserve,
        uint256 tokenBReserve
    );
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
     * @notice Modifier for operator access
     */
    modifier onlyOperator() {
        require(accessManager.isOperator(_msgSender()), "Only operator");
        _;
    }
    
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
    ) external override onlyOperator {
        // Sort tokens to ensure consistent hashing
        (address token0, address token1) = tokenA < tokenB 
            ? (tokenA, tokenB) 
            : (tokenB, tokenA);
        
        // Get pool hash
        bytes32 poolHash = _computePoolHash(dex, token0, token1, fee);
        
        // Check if pool exists
        if (!_poolData[poolHash].exists) {
            _poolHashes.push(poolHash);
            _poolData[poolHash].exists = true;
        }
        
        // Update pool data
        _poolData[poolHash].liquidity = liquidity;
        
        // Ensure reserves match the sorted token order
        if (tokenA < tokenB) {
            _poolData[poolHash].tokenAReserve = tokenAReserve;
            _poolData[poolHash].tokenBReserve = tokenBReserve;
        } else {
            _poolData[poolHash].tokenAReserve = tokenBReserve;
            _poolData[poolHash].tokenBReserve = tokenAReserve;
        }
        
        _poolData[poolHash].lastUpdateTimestamp = block.timestamp;
        
        // Emit update event
        emit PoolDataUpdated(
            poolHash,
            dex,
            token0,
            token1,
            fee,
            liquidity,
            _poolData[poolHash].tokenAReserve,
            _poolData[poolHash].tokenBReserve
        );
    }
    
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
    ) external pure override returns (bytes32) {
        // Sort tokens to ensure consistent hashing
        (address token0, address token1) = tokenA < tokenB 
            ? (tokenA, tokenB) 
            : (tokenB, tokenA);
            
        return _computePoolHash(dex, token0, token1, fee);
    }
    
    /**
     * @notice Get liquidity data for a pool
     * @param poolHash The pool hash
     * @return liquidity The pool liquidity
     * @return tokenAReserve The reserve of tokenA
     * @return tokenBReserve The reserve of tokenB
     * @return lastUpdateTimestamp Last update timestamp
     */
    function getPoolData(bytes32 poolHash) external view override returns (
        uint256 liquidity,
        uint256 tokenAReserve,
        uint256 tokenBReserve,
        uint256 lastUpdateTimestamp
    ) {
        require(_poolData[poolHash].exists, "Pool does not exist");
        
        return (
            _poolData[poolHash].liquidity,
            _poolData[poolHash].tokenAReserve,
            _poolData[poolHash].tokenBReserve,
            _poolData[poolHash].lastUpdateTimestamp
        );
    }
    
    /**
     * @notice Get all registered pool hashes
     * @return Array of pool hashes
     */
    function getAllPoolHashes() external view returns (bytes32[] memory) {
        return _poolHashes;
    }
    
    /**
     * @notice Get the count of registered pools
     * @return The number of pools
     */
    function getPoolCount() external view returns (uint256) {
        return _poolHashes.length;
    }
    
    /**
     * @notice Compute pool hash from parameters
     * @param dex The DEX index
     * @param token0 The first token (must be the lower address)
     * @param token1 The second token (must be the higher address)
     * @param fee The pool fee
     * @return The pool hash
     */
    function _computePoolHash(
        uint8 dex,
        address token0,
        address token1,
        uint24 fee
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(dex, token0, token1, fee));
    }
    
    /**
     * @notice Check if a pool exists
     * @param poolHash The pool hash
     * @return Whether the pool exists
     */
    function poolExists(bytes32 poolHash) external view returns (bool) {
        return _poolData[poolHash].exists;
    }
    
    /**
     * @notice Get the timestamp of the last update for a pool
     * @param poolHash The pool hash
     * @return The last update timestamp
     */
    function getLastUpdateTimestamp(bytes32 poolHash) external view returns (uint256) {
        require(_poolData[poolHash].exists, "Pool does not exist");
        return _poolData[poolHash].lastUpdateTimestamp;
    }
}
