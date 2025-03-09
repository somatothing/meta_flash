// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

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
    
    /**
     * @notice Rescue tokens that might be stuck in this contract
     * @param token Token address
     * @param to Address to send tokens to
     * @param amount Amount to rescue
     */
    function rescueTokens(address token, address to, uint256 amount) external;
    
    /**
     * @notice Set the meta-transaction router
     * @param _metaTxRouter Address of the meta-transaction router
     */
    function setMetaTxRouter(address _metaTxRouter) external;
}