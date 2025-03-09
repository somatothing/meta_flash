// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

/**
 * @title IUniswapV3Pool
 * @notice Interface for Uniswap V3 Pool
 */
interface IUniswapV3Pool {
    /**
     * @notice The first of the two tokens of the pool, sorted by address
     * @return The token address
     */
    function token0() external view returns (address);
    
    /**
     * @notice The second of the two tokens of the pool, sorted by address
     * @return The token address
     */
    function token1() external view returns (address);
    
    /**
     * @notice The pool's fee in hundredths of a bip, i.e. 1e-6
     * @return The fee
     */
    function fee() external view returns (uint24);
    
    /**
     * @notice Receive token0 and/or token1 and pay it back, plus a fee, in the callback
     * @param recipient The address to receive the borrowed tokens
     * @param amount0 The amount of token0 to lend
     * @param amount1 The amount of token1 to lend
     * @param data Any data to pass to the callback
     */
    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;
    
    /**
     * @notice The 0th storage slot in the pool stores many values, and is exposed as a single method to save gas
     * when accessed externally.
     * @return sqrtPriceX96 The current price of the pool as a sqrt(token1/token0) Q64.96 value
     * @return tick The current tick of the pool, i.e. log base 1.0001 of the current price
     * @return observationIndex The index of the last oracle observation
     * @return observationCardinality The current maximum number of observations stored in the pool
     * @return observationCardinalityNext The next maximum number of observations, to be updated when observation cardinality is next increased
     * @return feeProtocol The protocol fee for both tokens of the pool
     * @return unlocked Whether the pool is currently locked to reentrancy
     */
    function slot0() external view returns (
        uint160 sqrtPriceX96,
        int24 tick,
        uint16 observationIndex,
        uint16 observationCardinality,
        uint16 observationCardinalityNext,
        uint8 feeProtocol,
        bool unlocked
    );
    
    /**
     * @notice Returns the amounts of token0 and token1 held in protocol fees
     * @return token0 The amount of token0
     * @return token1 The amount of token1
     */
    function protocolFees() external view returns (
        uint128 token0,
        uint128 token1
    );
    
    /**
     * @notice Returns the liquidity of the pool as of the last observation
     * @return The liquidity value
     */
    function liquidity() external view returns (uint128);
}

/**
 * @title IUniswapV3FlashCallback
 * @notice Interface for callback when using Uniswap V3 flash loans
 */
interface IUniswapV3FlashCallback {
    /**
     * @notice Called to `msg.sender` after executing a flash via IUniswapV3Pool#flash
     * @param fee0 The fee amount in token0 due for the flash
     * @param fee1 The fee amount in token1 due for the flash
     * @param data Data passed through from the flash initiator call
     */
    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external;
}