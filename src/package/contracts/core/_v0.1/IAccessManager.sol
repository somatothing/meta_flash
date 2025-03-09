// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title IAccessManager
 * @notice Interface for access control management
 */
interface IAccessManager {
    /**
     * @notice Check if an account is an admin
     * @param account The account to check
     * @return True if the account is an admin
     */
    function isAdmin(address account) external view returns (bool);
    
    /**
     * @notice Check if an account is an operator
     * @param account The account to check
     * @return True if the account is an operator
     */
    function isOperator(address account) external view returns (bool);
    
    /**
     * @notice Grant admin role to an account
     * @param account The account to grant admin to
     */
    function grantAdmin(address account) external;
    
    /**
     * @notice Revoke admin role from an account
     * @param account The account to revoke admin from
     */
    function revokeAdmin(address account) external;
    
    /**
     * @notice Grant operator role to an account
     * @param account The account to grant operator to
     */
    function grantOperator(address account) external;
    
    /**
     * @notice Revoke operator role from an account
     * @param account The account to revoke operator from
     */
    function revokeOperator(address account) external;
    
    /**
     * @notice Set the meta-transaction router
     * @param _metaTxRouter Address of the meta-transaction router
     */
    function setMetaTxRouter(address _metaTxRouter) external;
}