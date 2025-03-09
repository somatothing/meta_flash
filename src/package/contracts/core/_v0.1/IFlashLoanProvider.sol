// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

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
    
    /**
     * @notice Set contract dependencies
     * @param _dexAdapter DEX adapter address
     * @param _pathRegistry Path registry address
     */
    function setDependencies(
        address _dexAdapter,
        address _pathRegistry
    ) external;
    
    /**
     * @notice Set the meta-transaction router
     * @param _metaTxRouter Address of the meta-transaction router
     */
    function setMetaTxRouter(address _metaTxRouter) external;
    
    /**
     * @notice Rescue tokens that might be stuck in this contract
     * @param token Token address
     * @param to Address to send tokens to
     * @param amount Amount to rescue
     */
    function rescueTokens(address token, address to, uint256 amount) external;
}