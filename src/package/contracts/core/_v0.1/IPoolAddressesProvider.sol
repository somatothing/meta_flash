// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title IPoolAddressesProvider
 * @author Aave
 * @notice Defines the interface for the AAVE Pool Addresses Provider
 */
interface IPoolAddressesProvider {
    function getPool() external view returns (address);
    function getPoolConfigurator() external view returns (address);
    function getPriceOracle() external view returns (address);
    function getACLManager() external view returns (address);
    function getMarketId() external view returns (string memory);
}