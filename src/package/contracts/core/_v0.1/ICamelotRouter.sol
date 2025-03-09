// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title ICamelotRouter
 * @notice Interface for Camelot router's key functions
 */
interface ICamelotRouter {
    /**
     * @notice Swap exact tokens for tokens
     * @param amountIn The amount of input tokens
     * @param amountOutMin The minimum amount of output tokens
     * @param path The token path for the swap
     * @param to The recipient address
     * @param deadline The deadline timestamp
     * @return amounts Array of amounts for each step in the path
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
    
    /**
     * @notice Get amounts out for a given input amount
     * @param amountIn The input amount
     * @param path The token path for the swap
     * @return amounts Array of amounts for each step in the path
     */
    function getAmountsOut(
        uint256 amountIn,
        address[] calldata path
    ) external view returns (uint256[] memory amounts);
    
    /**
     * @notice Get amounts in for a given output amount
     * @param amountOut The output amount
     * @param path The token path for the swap
     * @return amounts Array of amounts for each step in the path
     */
    function getAmountsIn(
        uint256 amountOut,
        address[] calldata path
    ) external view returns (uint256[] memory amounts);
}