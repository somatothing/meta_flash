// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

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
    
    /**
     * @notice Set the meta-transaction router
     * @param _metaTxRouter Address of the meta-transaction router
     */
    function setMetaTxRouter(address _metaTxRouter) external;
}