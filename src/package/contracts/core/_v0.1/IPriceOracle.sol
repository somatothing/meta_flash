// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

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
    
    /**
     * @notice Set contract dependencies
     * @param _dexAdapter DEX adapter address
     */
    function setDependencies(address _dexAdapter) external;
    
    /**
     * @notice Update price feed for a token
     * @param token Token address
     * @param feed Price feed address
     */
    function setPriceFeed(address token, address feed) external;
    
    /**
     * @notice Update USD reference token
     * @param _usdReferenceToken New reference token
     */
    function setUSDReferenceToken(address _usdReferenceToken) external;
    
    /**
     * @notice Update WETH address
     * @param _weth New WETH address
     */
    function setWETH(address _weth) external;
    
    /**
     * @notice Set the meta-transaction router
     * @param _metaTxRouter Address of the meta-transaction router
     */
    function setMetaTxRouter(address _metaTxRouter) external;
}