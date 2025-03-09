// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./_v0.1/IFlashLoanProvider.sol";
import "./_v0.1/IAccessManager.sol";
import "./_v0.1/IDEXAdapter.sol";
import "./_v0.1/IPathRegistry.sol";
import "./_v0.1/IPool.sol";
import "./_v0.1/IBalancerVault.sol";
import "./_v0.1/IDODOFlashLoan.sol";
import "./_v0.1/IUniswapV3Pool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title FlashLoanProvider
 * @notice Provides a unified interface to execute flash loans across multiple protocols
 * @dev Supports Aave, Balancer, DODO, and Uniswap V3 flash loans
 */
contract FlashLoanProvider is IFlashLoanProvider {
    // Access manager
    IAccessManager public immutable accessManager;
    
    // DEX adapter for executing swaps
    IDEXAdapter public dexAdapter;
    
    // Path registry for getting path information
    IPathRegistry public pathRegistry;
    
    // Protocol contract addresses
    address public immutable aavePool;
    address public immutable balancerVault;
    address public immutable dodoApprove;
    
    // Meta-transaction router
    address public metaTxRouter;
    
    // Currently executing flash loan data
    FlashLoanCallbackData private _currentFlashLoan;
    
    // Events
    event FlashLoanExecuted(Protocol protocol, address token, uint256 amount, uint256 pathId, uint256 profit);
    event FlashLoanFailed(Protocol protocol, address token, uint256 amount, uint256 pathId, string reason);
    event MetaTxRouterUpdated(address indexed newRouter);
    
    /**
     * @notice Constructor
     * @param _accessManager Access manager address
     * @param _aavePool Aave lending pool address
     * @param _balancerVault Balancer vault address
     * @param _dodoApprove DODO approve address
     */
    constructor(
        address _accessManager,
        address _aavePool,
        address _balancerVault,
        address _dodoApprove
    ) {
        accessManager = IAccessManager(_accessManager);
        aavePool = _aavePool;
        balancerVault = _balancerVault;
        dodoApprove = _dodoApprove;
    }
    
    /**
     * @notice Set contract dependencies
     * @param _dexAdapter DEX adapter address
     * @param _pathRegistry Path registry address
     */
    function setDependencies(
        address _dexAdapter,
        address _pathRegistry
    ) external {
        require(accessManager.isAdmin(msg.sender), "Only admin");
        dexAdapter = IDEXAdapter(_dexAdapter);
        pathRegistry = IPathRegistry(_pathRegistry);
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
    ) external override onlyOperator returns (uint256 profit) {
        // Check if path exists and is active
        IPathRegistry.ArbitragePath memory path = pathRegistry.getPath(pathId);
        require(path.isActive, "Path is not active");
        require(path.tokens[0] == token, "Token mismatch with path");
        require(amount <= path.maxAmount, "Amount exceeds path maximum");
        
        try {
            if (protocol == Protocol.AAVE) {
                return _executeAaveFlashLoan(token, amount, pathId, minProfitBps);
            } else if (protocol == Protocol.BALANCER) {
                return _executeBalancerFlashLoan(token, amount, pathId, minProfitBps);
            } else if (protocol == Protocol.DODO) {
                return _executeDODOFlashLoan(token, amount, pathId, minProfitBps);
            } else if (protocol == Protocol.UNISWAP) {
                return _executeUniswapFlashLoan(token, amount, pathId, minProfitBps);
            } else {
                revert("Unsupported protocol");
            }
        } catch Error(string memory reason) {
            emit FlashLoanFailed(protocol, token, amount, pathId, reason);
            revert(reason);
        } catch {
            emit FlashLoanFailed(protocol, token, amount, pathId, "Unknown error");
            revert("Flash loan failed");
        }
    }
    
    /**
     * @notice Execute an Aave flash loan
     */
    function _executeAaveFlashLoan(
        address token,
        uint256 amount,
        uint256 pathId,
        uint256 minProfitBps
    ) internal returns (uint256) {
        // Prepare flash loan parameters
        address[] memory assets = new address[](1);
        assets[0] = token;
        
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        
        uint256[] memory modes = new uint256[](1);
        modes[0] = 0; // no debt mode, just flash loan
        
        // Store flash loan context
        _currentFlashLoan = FlashLoanCallbackData({
            protocol: Protocol.AAVE,
            initiator: _msgSender(),
            token: token,
            amount: amount,
            fee: 0,
            pathId: pathId,
            minProfitBps: minProfitBps
        });
        
        // Execute flash loan
        IPool(aavePool).flashLoan(
            address(this),
            assets,
            amounts,
            modes,
            address(this),
            abi.encode(_currentFlashLoan),
            0 // referral code
        );
        
        // Return profit (set in the callback)
        return _currentFlashLoan.fee;
    }
    
    /**
     * @notice Execute a Balancer flash loan
     */
    function _executeBalancerFlashLoan(
        address token,
        uint256 amount,
        uint256 pathId,
        uint256 minProfitBps
    ) internal returns (uint256) {
        // Prepare flash loan parameters
        address[] memory tokens = new address[](1);
        tokens[0] = token;
        
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        
        // Store flash loan context
        _currentFlashLoan = FlashLoanCallbackData({
            protocol: Protocol.BALANCER,
            initiator: _msgSender(),
            token: token,
            amount: amount,
            fee: 0,
            pathId: pathId,
            minProfitBps: minProfitBps
        });
        
        // Execute flash loan
        IBalancerVault(balancerVault).flashLoan(
            address(this),
            tokens,
            amounts,
            abi.encode(_currentFlashLoan)
        );
        
        // Return profit (set in the callback)
        return _currentFlashLoan.fee;
    }
    
    /**
     * @notice Execute a DODO flash loan
     */
    function _executeDODOFlashLoan(
        address token,
        uint256 amount,
        uint256 pathId,
        uint256 minProfitBps
    ) internal returns (uint256) {
        // Store flash loan context
        _currentFlashLoan = FlashLoanCallbackData({
            protocol: Protocol.DODO,
            initiator: _msgSender(),
            token: token,
            amount: amount,
            fee: 0,
            pathId: pathId,
            minProfitBps: minProfitBps
        });
        
        // Execute flash loan
        // First get the actual DODO pool for this token
        address dodoPool = _getDODOPool(token);
        IDODOFlashLoan(dodoPool).flashLoan(
            amount,
            abi.encode(_currentFlashLoan)
        );
        
        // Return profit (set in the callback)
        return _currentFlashLoan.fee;
    }
    
    /**
     * @notice Execute a Uniswap V3 flash loan
     */
    function _executeUniswapFlashLoan(
        address token,
        uint256 amount,
        uint256 pathId,
        uint256 minProfitBps
    ) internal returns (uint256) {
        // Store flash loan context
        _currentFlashLoan = FlashLoanCallbackData({
            protocol: Protocol.UNISWAP,
            initiator: _msgSender(),
            token: token,
            amount: amount,
            fee: 0,
            pathId: pathId,
            minProfitBps: minProfitBps
        });
        
        // Get a Uniswap V3 pool for this token
        address uniPool = _getUniswapPool(token);
        
        // Use fee0 or fee1 based on whether our token is token0 or token1
        address token0 = IUniswapV3Pool(uniPool).token0();
        uint256 amount0 = token == token0 ? amount : 0;
        uint256 amount1 = token == token0 ? 0 : amount;
        
        // Execute flash loan
        IUniswapV3Pool(uniPool).flash(
            address(this),
            amount0,
            amount1,
            abi.encode(_currentFlashLoan)
        );
        
        // Return profit (set in the callback)
        return _currentFlashLoan.fee;
    }
    
    /**
     * @notice Callback for Aave flash loans
     */
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        require(msg.sender == aavePool, "Callback not from Aave");
        require(initiator == address(this), "Invalid initiator");
        
        // Decode params
        FlashLoanCallbackData memory flashLoanData = abi.decode(params, (FlashLoanCallbackData));
        
        // Execute arbitrage
        _executeArbitrage(
            flashLoanData.token,
            flashLoanData.amount,
            flashLoanData.pathId,
            flashLoanData.minProfitBps,
            amounts[0] + premiums[0]
        );
        
        // Approve repayment
        IERC20(assets[0]).approve(aavePool, amounts[0] + premiums[0]);
        
        return true;
    }
    
    /**
     * @notice Callback for Balancer flash loans
     */
    function receiveFlashLoan(
        address[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata feeAmounts,
        bytes calldata params
    ) external {
        require(msg.sender == balancerVault, "Callback not from Balancer");
        
        // Decode params
        FlashLoanCallbackData memory flashLoanData = abi.decode(params, (FlashLoanCallbackData));
        
        // Execute arbitrage
        _executeArbitrage(
            flashLoanData.token,
            flashLoanData.amount,
            flashLoanData.pathId,
            flashLoanData.minProfitBps,
            amounts[0] + feeAmounts[0]
        );
        
        // Approve repayment
        IERC20(tokens[0]).approve(balancerVault, amounts[0] + feeAmounts[0]);
    }
    
    /**
     * @notice Callback for DODO flash loans
     */
    function DSPFlashLoanCall(
        address sender,
        uint256 baseAmount,
        uint256 quoteAmount,
        bytes calldata data
    ) external {
        // Sender verification will depend on how DODO implements this
        // This may need adjustment based on actual DODO implementation
        
        // Decode params
        FlashLoanCallbackData memory flashLoanData = abi.decode(data, (FlashLoanCallbackData));
        
        // Calculate total to repay (principal only, no fees in DODO)
        uint256 totalToRepay = baseAmount;
        
        // Execute arbitrage
        _executeArbitrage(
            flashLoanData.token,
            flashLoanData.amount,
            flashLoanData.pathId,
            flashLoanData.minProfitBps,
            totalToRepay
        );
        
        // Repay loan directly
        IERC20(flashLoanData.token).transfer(msg.sender, totalToRepay);
    }
    
    /**
     * @notice Callback for Uniswap V3 flash loans
     */
    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external {
        // Need to verify sender is a legitimate Uniswap V3 pool
        // In production, would need a list of valid pools
        
        // Decode params
        FlashLoanCallbackData memory flashLoanData = abi.decode(data, (FlashLoanCallbackData));
        
        // Get token and fee
        address token = flashLoanData.token;
        uint256 fee = IUniswapV3Pool(msg.sender).token0() == token ? fee0 : fee1;
        
        // Calculate total to repay
        uint256 totalToRepay = flashLoanData.amount + fee;
        
        // Execute arbitrage
        _executeArbitrage(
            flashLoanData.token,
            flashLoanData.amount,
            flashLoanData.pathId,
            flashLoanData.minProfitBps,
            totalToRepay
        );
        
        // Repay loan directly
        IERC20(token).transfer(msg.sender, totalToRepay);
    }
    
    /**
     * @notice Execute arbitrage swaps using borrowed funds
     * @param token Flash-loaned token
     * @param amount Borrowed amount
     * @param pathId Path ID to execute
     * @param minProfitBps Minimum profit in basis points
     * @param repayAmount Amount to repay (including fees)
     */
    function _executeArbitrage(
        address token,
        uint256 amount,
        uint256 pathId,
        uint256 minProfitBps,
        uint256 repayAmount
    ) internal {
        // Get path information
        IPathRegistry.ArbitragePath memory path = pathRegistry.getPath(pathId);
        require(path.isActive, "Path is not active");
        require(path.tokens[0] == token, "Token mismatch with path");
        
        // Initial balance
        uint256 initialBalance = IERC20(token).balanceOf(address(this));
        
        // Execute swaps through each hop in the path
        uint256 currentAmount = amount;
        for (uint256 i = 0; i < path.tokens.length - 1; i++) {
            address tokenIn = path.tokens[i];
            address tokenOut = path.tokens[i + 1];
            uint24 poolFee = path.poolFees[i];
            
            // Execute swap
            currentAmount = dexAdapter.swap(
                IDEXAdapter.DEX(path.dexes[i]),
                tokenIn,
                tokenOut,
                currentAmount,
                poolFee,
                address(this)
            );
        }
        
        // Final balance
        uint256 finalBalance = IERC20(token).balanceOf(address(this));
        
        // Calculate profit
        uint256 profit = 0;
        if (finalBalance > repayAmount) {
            profit = finalBalance - repayAmount;
            
            // Check minimum profit
            uint256 profitBps = (profit * 10000) / amount;
            require(profitBps >= minProfitBps, "Profit below minimum threshold");
            
            // Update current flash loan fee (for returning profit)
            _currentFlashLoan.fee = profit;
            
            // Emit success event
            emit FlashLoanExecuted(
                _currentFlashLoan.protocol,
                token,
                amount,
                pathId,
                profit
            );
        } else {
            revert("Arbitrage not profitable");
        }
    }
    
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
    ) external view override returns (uint256) {
        if (protocol == Protocol.AAVE) {
            return 9; // 0.09% for Aave
        } else if (protocol == Protocol.BALANCER) {
            return 0; // Balancer has no fee
        } else if (protocol == Protocol.DODO) {
            return 0; // DODO has no fee
        } else if (protocol == Protocol.UNISWAP) {
            address pool = _getUniswapPool(token);
            return IUniswapV3Pool(pool).fee() / 100; // Convert to basis points
        } else {
            revert("Unsupported protocol");
        }
    }
    
    /**
     * @notice Get maximum loan size for a token on a protocol
     * @param protocol The protocol to check
     * @param token The token to check
     * @return The maximum loan size
     */
    function getMaxLoanSize(
        Protocol protocol,
        address token
    ) external view override returns (uint256) {
        // In a real implementation, would query protocol for token liquidity
        // This is a simplified placeholder
        if (protocol == Protocol.AAVE) {
            return IERC20(token).balanceOf(aavePool) / 2;
        } else if (protocol == Protocol.BALANCER) {
            // Would need to get the specific pool for this token
            return IERC20(token).balanceOf(balancerVault) / 2;
        } else if (protocol == Protocol.DODO) {
            address pool = _getDODOPool(token);
            return IERC20(token).balanceOf(pool) / 2;
        } else if (protocol == Protocol.UNISWAP) {
            address pool = _getUniswapPool(token);
            if (token == IUniswapV3Pool(pool).token0()) {
                return IERC20(token).balanceOf(pool) / 2;
            } else {
                return IERC20(token).balanceOf(pool) / 2;
            }
        } else {
            revert("Unsupported protocol");
        }
    }
    
    /**
     * @notice Get a DODO pool for a token
     * @dev In a real implementation, would maintain a registry
     */
    function _getDODOPool(address token) internal view returns (address) {
        // Placeholder - in a real implementation, would need a registry
        return address(0);
    }
    
    /**
     * @notice Get a Uniswap V3 pool for a token
     * @dev In a real implementation, would maintain a registry
     */
    function _getUniswapPool(address token) internal view returns (address) {
        // Placeholder - in a real implementation, would need a registry
        return address(0);
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
