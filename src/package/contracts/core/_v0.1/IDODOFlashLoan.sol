// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title IDODOFlashLoan
 * @notice Interface for DODO flash loan provider
 */
interface IDODOFlashLoan {
    /**
     * @notice Execute a flash loan
     * @param baseAmount The amount of base token to borrow
     * @param data Additional data to pass to the callback
     */
    function flashLoan(
        uint256 baseAmount,
        bytes calldata data
    ) external;
    
    /**
     * @notice Flash loan callback interface that borrowers must implement
     * @param sender The original sender of the flash loan
     * @param baseAmount The amount of base token borrowed
     * @param quoteAmount The amount of quote token borrowed (usually 0)
     * @param data Additional data passed from the flash loan call
     */
    function DSPFlashLoanCall(
        address sender,
        uint256 baseAmount,
        uint256 quoteAmount,
        bytes calldata data
    ) external;
    
    /**
     * @notice Get the base token of the pool
     * @return The base token address
     */
    function _BASE_TOKEN_() external view returns (address);
    
    /**
     * @notice Get the quote token of the pool
     * @return The quote token address
     */
    function _QUOTE_TOKEN_() external view returns (address);
}