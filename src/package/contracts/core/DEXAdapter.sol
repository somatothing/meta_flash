// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./_v0.1/IDEXAdapter.sol";
import "./_v0.1/IAccessManager.sol";
import "./_v0.1/ISwapRouter.sol";
import "./_v0.1/IBalancerVault.sol";
import "./_v0.1/ICamelotRouter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DEXAdapter
 * @notice Provides a unified interface to interact with multiple DEXes
 * @dev Handles swaps on Uniswap V3, SushiSwap, Camelot, and Balancer
 */
contract DEXAdapter is IDEXAdapter {
    // Access manager for permissions
    IAccessManager public immutable accessManager;
    
    // DEX router addresses
    address public immutable uniswapRouter;
    address public immutable sushiswapRouter;
    address public immutable camelotRouter;
    address public immutable balancerVault;
    
    // Meta-transaction router
    address public metaTxRouter;
    
    // Events
    event SwapExecuted(uint8 indexed dex, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);
    event QuoteFailed(uint8 indexed dex, address indexed tokenIn, address indexed tokenOut, string reason);
    event MetaTxRouterUpdated(address indexed newRouter);
    
    /**
     * @notice Constructor
     * @param _accessManager Access manager address
     * @param _uniswapRouter Uniswap V3 router address
     * @param _sushiswapRouter SushiSwap router address
     * @param _camelotRouter Camelot router address
     * @param _balancerVault Balancer vault address
     */
    constructor(
        address _accessManager,
        address _uniswapRouter,
        address _sushiswapRouter,
        address _camelotRouter,
        address _balancerVault
    ) {
        accessManager = IAccessManager(_accessManager);
        uniswapRouter = _uniswapRouter;
        sushiswapRouter = _sushiswapRouter;
        camelotRouter = _camelotRouter;
        balancerVault = _balancerVault;
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
    ) external override onlyOperator returns (uint256 amountOut) {
        // Ensure tokens are approved for the appropriate router
        _approveToken(tokenIn, _getRouterForDex(dex), amountIn);
        
        // Execute swap based on DEX
        if (dex == DEX.UNISWAP) {
            amountOut = _swapUniswap(tokenIn, tokenOut, amountIn, poolFee, recipient);
        } else if (dex == DEX.SUSHISWAP) {
            amountOut = _swapSushiSwap(tokenIn, tokenOut, amountIn, poolFee, recipient);
        } else if (dex == DEX.CAMELOT) {
            amountOut = _swapCamelot(tokenIn, tokenOut, amountIn, recipient);
        } else if (dex == DEX.BALANCER) {
            amountOut = _swapBalancer(tokenIn, tokenOut, amountIn, recipient);
        } else {
            revert("Unsupported DEX");
        }
        
        emit SwapExecuted(uint8(dex), tokenIn, tokenOut, amountIn, amountOut);
        
        return amountOut;
    }
    
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
    ) external view override returns (uint256 amountOut) {
        try this._getQuoteInternal(dex, tokenIn, tokenOut, amountIn, poolFee) returns (uint256 amount) {
            return amount;
        } catch Error(string memory reason) {
            // We can't emit events in view functions, so we just return 0
            return 0;
        } catch {
            return 0;
        }
    }
    
    /**
     * @notice Internal function to get quote (separated to handle errors)
     * @dev This is called via this.function() to allow try/catch in view functions
     */
    function _getQuoteInternal(
        DEX dex,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint24 poolFee
    ) external view returns (uint256) {
        if (dex == DEX.UNISWAP) {
            return _quoteUniswap(tokenIn, tokenOut, amountIn, poolFee);
        } else if (dex == DEX.SUSHISWAP) {
            return _quoteSushiSwap(tokenIn, tokenOut, amountIn, poolFee);
        } else if (dex == DEX.CAMELOT) {
            return _quoteCamelot(tokenIn, tokenOut, amountIn);
        } else if (dex == DEX.BALANCER) {
            return _quoteBalancer(tokenIn, tokenOut, amountIn);
        } else {
            revert("Unsupported DEX");
        }
    }
    
    /**
     * @notice Get the router address for a specific DEX
     * @param dex The DEX
     * @return The router address
     */
    function _getRouterForDex(DEX dex) internal view returns (address) {
        if (dex == DEX.UNISWAP) {
            return uniswapRouter;
        } else if (dex == DEX.SUSHISWAP) {
            return sushiswapRouter;
        } else if (dex == DEX.CAMELOT) {
            return camelotRouter;
        } else if (dex == DEX.BALANCER) {
            return balancerVault;
        } else {
            revert("Unsupported DEX");
        }
    }
    
    /**
     * @notice Approve tokens for a specific router
     * @param token The token to approve
     * @param router The router to approve for
     * @param amount The amount to approve
     */
    function _approveToken(address token, address router, uint256 amount) internal {
        IERC20(token).approve(router, amount);
    }
    
    /**
     * @notice Execute a swap on Uniswap V3
     */
    function _swapUniswap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint24 poolFee,
        address recipient
    ) internal returns (uint256 amountOut) {
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: poolFee,
            recipient: recipient,
            deadline: block.timestamp + 300, // 5 minutes
            amountIn: amountIn,
            amountOutMinimum: 0, // No slippage check in adapter
            sqrtPriceLimitX96: 0
        });
        
        return ISwapRouter(uniswapRouter).exactInputSingle(params);
    }
    
    /**
     * @notice Execute a swap on SushiSwap
     * @dev SushiSwap on Arbitrum also uses Uniswap V3 style interface
     */
    function _swapSushiSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint24 poolFee,
        address recipient
    ) internal returns (uint256 amountOut) {
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: poolFee,
            recipient: recipient,
            deadline: block.timestamp + 300, // 5 minutes
            amountIn: amountIn,
            amountOutMinimum: 0, // No slippage check in adapter
            sqrtPriceLimitX96: 0
        });
        
        return ISwapRouter(sushiswapRouter).exactInputSingle(params);
    }
    
    /**
     * @notice Execute a swap on Camelot
     */
    function _swapCamelot(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        address recipient
    ) internal returns (uint256 amountOut) {
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        
        uint256[] memory amounts = ICamelotRouter(camelotRouter).swapExactTokensForTokens(
            amountIn,
            0, // Min amount out (no slippage check)
            path,
            recipient,
            block.timestamp + 300 // 5 minutes
        );
        
        return amounts[amounts.length - 1];
    }
    
    /**
     * @notice Execute a swap on Balancer
     */
    function _swapBalancer(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        address recipient
    ) internal returns (uint256 amountOut) {
        // Create single swap struct
        IBalancerVault.SingleSwap memory singleSwap = IBalancerVault.SingleSwap({
            poolId: _getBalancerPoolId(tokenIn, tokenOut),
            kind: IBalancerVault.SwapKind.GIVEN_IN,
            assetIn: tokenIn,
            assetOut: tokenOut,
            amount: amountIn,
            userData: ""
        });
        
        // Fund management
        IBalancerVault.FundManagement memory funds = IBalancerVault.FundManagement({
            sender: address(this),
            fromInternalBalance: false,
            recipient: payable(recipient),
            toInternalBalance: false
        });
        
        // Execute swap
        return IBalancerVault(balancerVault).swap(
            singleSwap,
            funds,
            0, // Min amount out (no slippage check)
            block.timestamp + 300 // 5 minutes
        );
    }
    
    /**
     * @notice Get quote for Uniswap V3
     */
    function _quoteUniswap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint24 poolFee
    ) internal view returns (uint256) {
        // For a real implementation, would use a quoter contract
        // This is a simplified placeholder
        return amountIn * 98 / 100; // Simplified 2% slippage estimate
    }
    
    /**
     * @notice Get quote for SushiSwap
     */
    function _quoteSushiSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint24 poolFee
    ) internal view returns (uint256) {
        // Simplified placeholder
        return amountIn * 97 / 100; // Simplified 3% slippage estimate
    }
    
    /**
     * @notice Get quote for Camelot
     */
    function _quoteCamelot(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal view returns (uint256) {
        // Simplified placeholder
        return amountIn * 97 / 100; // Simplified 3% slippage estimate
    }
    
    /**
     * @notice Get quote for Balancer
     */
    function _quoteBalancer(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal view returns (uint256) {
        // Simplified placeholder
        return amountIn * 96 / 100; // Simplified 4% slippage estimate
    }
    
    /**
     * @notice Get Balancer pool ID for a token pair
     * @dev In a real implementation, would need a mapping or lookup mechanism
     */
    function _getBalancerPoolId(address tokenA, address tokenB) internal pure returns (bytes32) {
        // Placeholder - in a real implementation, would need a registry
        return bytes32(0);
    }
    
    /**
     * @notice Rescue tokens that might be stuck in this contract
     * @param token Token address
     * @param to Address to send tokens to
     * @param amount Amount to rescue
     */
    function rescueTokens(address token, address to, uint256 amount) external {
        require(accessManager.isAdmin(msg.sender), "Only admin");
        IERC20(token).transfer(to, amount);
    }
}
