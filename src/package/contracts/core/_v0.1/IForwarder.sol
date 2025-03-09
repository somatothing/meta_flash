// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title IForwarder
 * @notice Interface for a meta-transaction forwarder/relayer
 */
interface IForwarder {
    /**
     * @notice Forward request structure
     */
    struct ForwardRequest {
        address from;
        address to;
        uint256 value;
        uint256 gas;
        uint256 nonce;
        bytes data;
    }
    
    /**
     * @notice Get the nonce for an account
     * @param from The account to query
     * @return The current nonce
     */
    function getNonce(address from) external view returns (uint256);
    
    /**
     * @notice Verify a request signature
     * @param req The forward request
     * @param signature The signature to verify
     * @return valid Whether the signature is valid
     */
    function verify(
        ForwardRequest calldata req,
        bytes calldata signature
    ) external view returns (bool);
    
    /**
     * @notice Execute a meta-transaction
     * @param req The forward request
     * @param signature The signature authorizing the request
     * @return success Whether the execution was successful
     * @return returnData The return data from the call
     */
    function execute(
        ForwardRequest calldata req,
        bytes calldata signature
    ) external payable returns (bool success, bytes memory returnData);
}
