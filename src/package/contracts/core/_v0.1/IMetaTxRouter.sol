// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./_v0.1/IAccessManager.sol";

/**
 * @title MetaTxRouter
 * @notice Handles meta-transactions for the arbitrage system
 * @dev Enables gasless transactions for users
 */
contract MetaTxRouter {
    // Request structure
    struct MetaTxRequest {
        address signer;
        address target;
        bytes data;
        uint256 nonce;
        uint256 deadline;
        bytes signature;
    }
    
    // Access manager reference
    IAccessManager public immutable accessManager;
    
    // EIP-712 domain separator
    bytes32 private immutable _DOMAIN_SEPARATOR;
    
    // Meta-transaction typehash
    bytes32 public constant META_TX_TYPEHASH = keccak256(
        "MetaTxRequest(address signer,address target,bytes data,uint256 nonce,uint256 deadline)"
    );
    
    // Nonces for each address for replay protection
    mapping(address => uint256) private _nonces;
    
    // Events
    event MetaTransactionExecuted(address indexed signer, address indexed relayer, bytes4 functionSelector, bool success);
    
    /**
     * @notice Constructor
     * @param _accessManager Address of the access manager contract
     */
    constructor(address _accessManager) {
        accessManager = IAccessManager(_accessManager);
        
        // Initialize domain separator for EIP-712
        _DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("ArbitrageMetaTxRouter")),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }
    
    /**
     * @notice Execute a meta-transaction
     * @param req The meta-transaction request
     * @return result The return data from the called function
     */
    function executeMetaTransaction(MetaTxRequest calldata req) external returns (bytes memory result) {
        // Check deadline
        require(req.deadline == 0 || req.deadline >= block.timestamp, "Meta-tx expired");
        
        // Verify nonce
        require(_nonces[req.signer] == req.nonce, "Invalid nonce");
        
        // Verify signature
        _verifyMetaTx(req);
        
        // Increment nonce
        _nonces[req.signer]++;
        
        // Extract function selector for logging
        bytes4 selector;
        if (req.data.length >= 4) {
            selector = bytes4(req.data[:4]);
        }
        
        // Execute the call
        (bool success, bytes memory returnData) = req.target.call(abi.encodePacked(req.data, req.signer));
        
        // Emit event
        emit MetaTransactionExecuted(req.signer, msg.sender, selector, success);
        
        // Handle result
        if (success) {
            return returnData;
        } else {
            // Revert with the same message if the call failed
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }
    }
    
    /**
     * @notice Get the current nonce for a signer
     * @param signer The address to get nonce for
     * @return The current nonce
     */
    function getNonce(address signer) external view returns (uint256) {
        return _nonces[signer];
    }
    
    /**
     * @notice Verify a meta-transaction signature
     * @param req The meta-transaction request
     */
    function _verifyMetaTx(MetaTxRequest calldata req) internal view {
        // Create hash of the request
        bytes32 structHash = keccak256(
            abi.encode(
                META_TX_TYPEHASH,
                req.signer,
                req.target,
                keccak256(req.data),
                req.nonce,
                req.deadline
            )
        );
        
        // Create EIP-712 compliant hash
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                _DOMAIN_SEPARATOR,
                structHash
            )
        );
        
        // Recover signer
        address signer = _recoverSigner(digest, req.signature);
        
        // Verify signature
        require(signer == req.signer, "Invalid signature");
    }
    
    /**
     * @notice Recover the signer from a signature
     * @param digest The hash that was signed
     * @param signature The signature
     * @return The recovered signer address
     */
    function _recoverSigner(bytes32 digest, bytes memory signature) internal pure returns (address) {
        require(signature.length == 65, "Invalid signature length");
        
        bytes32 r;
        bytes32 s;
        uint8 v;
        
        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }
        
        if (v < 27) {
            v += 27;
        }
        
        require(v == 27 || v == 28, "Invalid signature v value");
        
        address signer = ecrecover(digest, v, r, s);
        require(signer != address(0), "Invalid signature");
        
        return signer;
    }
    
    /**
     * @notice Get the domain separator for EIP-712
     * @return The domain separator
     */
    function getDomainSeparator() external view returns (bytes32) {
        return _DOMAIN_SEPARATOR;
    }
    
    /**
     * @notice Create meta-transaction data hash
     * @param req The request to hash (without signature)
     * @return The EIP-712 compliant hash
     */
    function getMetaTxHash(MetaTxRequest calldata req) external view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(
                META_TX_TYPEHASH,
                req.signer,
                req.target,
                keccak256(req.data),
                req.nonce,
                req.deadline
            )
        );
        
        return keccak256(
            abi.encodePacked(
                "\x19\x01",
                _DOMAIN_SEPARATOR,
                structHash
            )
        );
    }
}
