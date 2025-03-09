// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title IBalancerVault
 * @notice Interface for Balancer V2 Vault's key functions
 */
interface IBalancerVault {
    // Swap kinds
    enum SwapKind { GIVEN_IN, GIVEN_OUT }
    
    // SingleSwap data structure
    struct SingleSwap {
        bytes32 poolId;
        SwapKind kind;
        address assetIn;
        address assetOut;
        uint256 amount;
        bytes userData;
    }
    
    // FundManagement data structure
    struct FundManagement {
        address sender;
        bool fromInternalBalance;
        address payable recipient;
        bool toInternalBalance;
    }
    
    /**
     * @notice Execute a single swap
     * @param singleSwap The swap parameters
     * @param funds The fund management parameters
     * @param limit The price limit
     * @param deadline The deadline timestamp
     * @return The amount of tokens received
     */
    function swap(
        SingleSwap memory singleSwap,
        FundManagement memory funds,
        uint256 limit,
        uint256 deadline
    ) external payable returns (uint256);
    
    /**
     * @notice Execute a flash loan
     * @param recipient The recipient address (must implement required callback)
     * @param tokens Array of token addresses for the flash loan
     * @param amounts Array of amounts for each token
     * @param userData Additional user data to pass to the callback
     */
    function flashLoan(
        address recipient,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external;
    
    /**
     * @notice Get the pool tokens
     * @param poolId The pool ID
     * @return tokens Array of token addresses
     * @return balances Array of token balances
     * @return lastChangeBlock The last change block number
     */
    function getPoolTokens(
        bytes32 poolId
    ) external view returns (
        address[] memory tokens,
        uint256[] memory balances,
        uint256 lastChangeBlock
    );
}