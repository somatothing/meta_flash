// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title IPool
 * @notice Interface for Aave V3 Pool
 */
interface IPool {
    /**
     * @notice Allows users to borrow a specific amount of the reserve asset, provided that the borrower
     * already deposited enough collateral
     * @param asset The address of the asset to borrow
     * @param amount The amount to borrow
     * @param interestRateMode The interest rate mode (1 for stable, 2 for variable)
     * @param referralCode Referral code for potential rewards
     * @param onBehalfOf The address that will receive the borrowed assets
     */
    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;

    /**
     * @notice Deposits an amount of underlying asset into the reserve
     * @param asset The address of the asset to deposit
     * @param amount The amount to deposit
     * @param onBehalfOf The address that will receive the aTokens
     * @param referralCode Referral code for potential rewards
     */
    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    /**
     * @notice Withdraws an amount of underlying asset from the reserve
     * @param asset The address of the asset to withdraw
     * @param amount The amount to withdraw
     * @param to The address that will receive the withdrawn assets
     * @return The final amount withdrawn
     */
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256);

    /**
     * @notice Repays a borrowed amount on the specific reserve
     * @param asset The address of the asset to repay
     * @param amount The amount to repay
     * @param interestRateMode The interest rate mode (1 for stable, 2 for variable)
     * @param onBehalfOf The address of the user who will get his debt reduced
     * @return The final amount repaid
     */
    function repay(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address onBehalfOf
    ) external returns (uint256);

    /**
     * @notice Allows smartcontracts to access the liquidity of the pool within one transaction,
     * as long as the amount borrowed is returned.
     * @param receiverAddress The address of the contract receiving the funds
     * @param assets The addresses of the assets being flash-borrowed
     * @param amounts The amounts of the assets being flash-borrowed
     * @param modes Types of the debt to open if the flash loan is not returned (0 = no debt, 1 = stable, 2 = variable)
     * @param onBehalfOf The address that will receive the debt in the case of using on `modes` 1 or 2
     * @param params Variadic packed params to pass to the receiver as extra information
     * @param referralCode Referral code for potential rewards
     */
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata modes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;

    /**
     * @notice Returns the state and configuration of the reserve
     * @param asset The address of the asset
     * @return Data about the reserve
     */
    function getReserveData(address asset) external view returns (ReserveData memory);

    /**
     * @notice Returns the user account data across all reserves
     * @param user The address of the user
     * @return totalCollateralBase The total collateral of the user in the base currency
     * @return totalDebtBase The total debt of the user in the base currency
     * @return availableBorrowsBase The borrowing power left of the user in the base currency
     * @return currentLiquidationThreshold The liquidation threshold of the user
     * @return ltv The loan to value of the user
     * @return healthFactor The current health factor of the user
     */
    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );
}

/**
 * @title IPoolAddressesProvider
 * @notice Interface for the Pool Addresses Provider
 */
interface IPoolAddressesProvider {
    /**
     * @notice Returns the address of the Pool
     * @return The Pool address
     */
    function getPool() external view returns (address);
}

/**
 * @notice Structure for reserve data
 */
struct ReserveData {
    // Configuration data
    uint256 configuration;
    // Liquidity index
    uint128 liquidityIndex;
    // Current variable borrow rate
    uint128 variableBorrowIndex;
    // Current stable borrow rate
    uint128 currentLiquidityRate;
    // Current variable borrow rate
    uint128 currentVariableBorrowRate;
    // Current stable borrow rate
    uint128 currentStableBorrowRate;
    // Last update timestamp for reserve data
    uint40 lastUpdateTimestamp;
    // The id of the reserve
    uint16 id;
    // The underlying asset of the reserve
    address underlyingAsset;
    // Address of the interest rate strategy
    address interestRateAddress;
    // Address of the aToken representing the reserve
    address aTokenAddress;
    // Address of the stable debt token
    address stableDebtTokenAddress;
    // Address of the variable debt token
    address variableDebtTokenAddress;
}