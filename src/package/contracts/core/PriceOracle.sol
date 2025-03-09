// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./_v0.1/IPriceOracle.sol";
import "./_v0.1/IAccessManager.sol";
import "./_v0.1/IDEXAdapter.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title PriceOracle
 * @notice Provides price data for tokens from various sources
 * @dev Combines DEX pricing with external oracle data
 */
contract PriceOracle is IPriceOracle {
    // Access manager
    IAccessManager public immutable accessManager;
    
    // DEX adapter for getting quotes
    IDEXAdapter public dexAdapter;
    
    // Reference USD token (e.g., USDC)
    address public usdReferenceToken;
    
    // Chainlink price feeds for tokens
    mapping(address => address) public priceFeed;
    
    // WETH address
    address public weth;
    
    // Meta-transaction router
    address public metaTxRouter;
    
    // Events
    event PriceFeedUpdated(address indexed token, address indexed feed);
    event USDReferenceTokenUpdated(address indexed newToken);
    event WETHAddressUpdated(address indexed newWETH);
    event MetaTxRouterUpdated(address indexed newRouter);
    
    /**
     * @notice Constructor
     * @param _accessManager Access manager address
     * @param _usdReferenceToken Reference USD token (e.g., USDC)
     * @param _weth WETH token address
     */
    constructor(
        address _accessManager,
        address _usdReferenceToken,
        address _weth
    ) {
        accessManager = IAccessManager(_accessManager);
        usdReferenceToken = _usdReferenceToken;
        weth = _weth;
    }
    
    /**
     * @notice Set contract dependencies
     * @param _dexAdapter DEX adapter address
     */
    function setDependencies(address _dexAdapter) external {
        require(accessManager.isAdmin(msg.sender), "Only admin");
        dexAdapter = IDEXAdapter(_dexAdapter);
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
     * @notice Update price feed for a token
     * @param token Token address
     * @param feed Price feed address
     */
    function setPriceFeed(address token, address feed) external {
        require(accessManager.isAdmin(msg.sender), "Only admin");
        priceFeed[token] = feed;
        emit PriceFeedUpdated(token, feed);
    }
    
    /**
     * @notice Update USD reference token
     * @param _usdReferenceToken New reference token
     */
    function setUSDReferenceToken(address _usdReferenceToken) external {
        require(accessManager.isAdmin(msg.sender), "Only admin");
        usdReferenceToken = _usdReferenceToken;
        emit USDReferenceTokenUpdated(_usdReferenceToken);
    }
    
    /**
     * @notice Update WETH address
     * @param _weth New WETH address
     */
    function setWETH(address _weth) external {
        require(accessManager.isAdmin(msg.sender), "Only admin");
        weth = _weth;
        emit WETHAddressUpdated(_weth);
    }
    
    /**
     * @notice Get token price in USD
     * @param token The token to check
     * @return The price in USD (scaled by 10^18)
     */
    function getTokenPriceUSD(address token) external view override returns (uint256) {
        if (token == usdReferenceToken) {
            // Reference USD token has price of 1 USD
            return 10**18;
        }
        
        // Try to get from price feed
        address feed = priceFeed[token];
        if (feed != address(0)) {
            return _getPriceFromFeed(feed);
        }
        
        // Fall back to DEX pricing
        return _getTokenPriceFromDEXes(token, usdReferenceToken);
    }
    
    /**
     * @notice Get relative price between tokens
     * @param tokenA The base token
     * @param tokenB The quote token
     * @return The price of tokenA in tokenB (scaled by 10^18)
     */
    function getRelativePrice(address tokenA, address tokenB) external view override returns (uint256) {
        if (tokenA == tokenB) {
            return 10**18; // 1:1 ratio for same token
        }
        
        // Get from price feeds if available
        address feedA = priceFeed[tokenA];
        address feedB = priceFeed[tokenB];
        
        if (feedA != address(0) && feedB != address(0)) {
            uint256 priceA = _getPriceFromFeed(feedA);
            uint256 priceB = _getPriceFromFeed(feedB);
            
            return (priceA * 10**18) / priceB;
        }
        
        // Fall back to direct DEX pricing
        return _getTokenPriceFromDEXes(tokenA, tokenB);
    }
    
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
    ) external view override returns (uint8 bestDex, uint24 bestFee, uint256 amountOut) {
        uint256 bestAmountOut = 0;
        
        // Try all DEXes and fee tiers
        uint8[4] memory dexes = [uint8(0), uint8(1), uint8(2), uint8(3)]; // UNISWAP, SUSHISWAP, CAMELOT, BALANCER
        uint24[3] memory fees = [500, 3000, 10000]; // Common fee tiers: 0.05%, 0.3%, 1%
        
        for (uint8 i = 0; i < dexes.length; i++) {
            for (uint8 j = 0; j < fees.length; j++) {
                try dexAdapter.getQuote(
                    IDEXAdapter.DEX(dexes[i]),
                    tokenIn,
                    tokenOut,
                    amountIn,
                    fees[j]
                ) returns (uint256 quote) {
                    if (quote > bestAmountOut) {
                        bestAmountOut = quote;
                        bestDex = dexes[i];
                        bestFee = fees[j];
                    }
                } catch {
                    // Skip this combination if it fails
                    continue;
                }
            }
        }
        
        return (bestDex, bestFee, bestAmountOut);
    }
    
    /**
     * @notice Get price from Chainlink feed
     * @param feed Price feed address
     * @return Price from the feed (scaled by 10^18)
     */
    function _getPriceFromFeed(address feed) internal view returns (uint256) {
        // In production, would use Chainlink AggregatorV3Interface
        // This is a simplified placeholder that would be replaced with real code
        
        // Placeholder return - would actually call feed.latestRoundData()
        return 1000 * 10**18; // $1000 as a placeholder
    }
    
    /**
     * @notice Get token price from DEXes
     * @param tokenA Token to price
     * @param tokenB Token to price it in
     * @return Token price (scaled by 10^18)
     */
    function _getTokenPriceFromDEXes(address tokenA, address tokenB) internal view returns (uint256) {
        // Use standard 10^18 for calculations
        uint256 amountIn = 10**18;
        
        // Adjust for token decimals
        uint8 decimalsA = ERC20(tokenA).decimals();
        amountIn = amountIn * 10**decimalsA / 10**18;
        
        // Try to get best price from DEXes
        (uint8 bestDex, uint24 bestFee, uint256 amountOut) = this.getBestDexForSwap(tokenA, tokenB, amountIn);
        
        if (amountOut > 0) {
            // Convert back to 10^18 scale, accounting for token B decimals
            uint8 decimalsB = ERC20(tokenB).decimals();
            return amountOut * 10**18 / 10**decimalsB;
        }
        
        // If no direct path, try to price through WETH as an intermediary
        if (tokenA != weth && tokenB != weth) {
            uint256 priceInWETH = _getTokenPriceFromDEXes(tokenA, weth);
            uint256 wethInTokenB = _getTokenPriceFromDEXes(weth, tokenB);
            
            if (priceInWETH > 0 && wethInTokenB > 0) {
                return (priceInWETH * wethInTokenB) / 10**18;
            }
        }
        
        // Default fallback
        return 0;
    }
}
