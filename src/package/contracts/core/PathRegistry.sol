// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./_v0.1/IPathRegistry.sol";
import "./_v0.1/IAccessManager.sol";

/**
 * @title PathRegistry
 * @notice Manages and stores arbitrage paths
 * @dev Supports meta-transactions through access manager
 */
contract PathRegistry is IPathRegistry {
    // Access manager for permissions
    IAccessManager public immutable accessManager;
    
    // Path storage
    ArbitragePath[] private _paths;
    
    // Path categories mapping
    mapping(uint8 => uint256[]) private _pathsByCategory;
    
    // Meta-transaction router
    address public metaTxRouter;
    
    // Events
    event PathAdded(uint256 indexed pathId, address[] tokens, uint8[] dexes, string name, uint8 category);
    event PathUpdated(uint256 indexed pathId, bool isActive);
    event MetaTxRouterUpdated(address indexed newRouter);
    
    /**
     * @notice Constructor
     * @param _accessManager Address of the access manager
     */
    constructor(address _accessManager) {
        accessManager = IAccessManager(_accessManager);
    }
    
    /**
     * @notice Set the meta-transaction router
     * @param _metaTxRouter Address of the meta-transaction router
     */
    function setMetaTxRouter(address _metaTxRouter) external {
        require(accessManager.isAdmin(msg.sender), "Only admin");
        metaTxRouter = _metaTxRouter;
        emit MetaTxRouterUpdated(_metaTxRouter);
    }
    
    /**
     * @notice Get the sender for functions that support meta-transactions
     * @return The transaction sender (original signer for meta-transactions)
     */
    function _msgSender() internal view returns (address) {
        if (msg.sender == metaTxRouter) {
            // Extract signer from last 20 bytes of calldata
            return address(bytes20(msg.data[msg.data.length - 20:]));
        }
        return msg.sender;
    }
    
    /**
     * @notice Modifier for operator access
     */
    modifier onlyOperator() {
        require(accessManager.isOperator(_msgSender()), "Only operator");
        _;
    }
    
    /**
     * @notice Add a new arbitrage path
     * @param tokens Array of token addresses in the path
     * @param dexes Array of DEX indices for each swap
     * @param poolFees Array of pool fees for each swap
     * @param maxAmount Maximum amount for the path
     * @param name Human-readable name for the path
     * @param category Category index for the path
     * @return pathId The ID of the new path
     */
    function addPath(
        address[] calldata tokens,
        uint8[] calldata dexes,
        uint24[] calldata poolFees,
        uint256 maxAmount,
        string calldata name,
        uint8 category
    ) external override onlyOperator returns (uint256 pathId) {
        // Validate inputs
        require(tokens.length >= 3, "Path must have at least 3 tokens");
        require(dexes.length == tokens.length - 1, "Dexes array length mismatch");
        require(poolFees.length == tokens.length - 1, "Fees array length mismatch");
        require(tokens[0] == tokens[tokens.length - 1], "Path must start and end with the same token");
        
        // Create path
        _paths.push(ArbitragePath({
            tokens: tokens,
            dexes: dexes,
            poolFees: poolFees,
            isActive: true,
            maxAmount: maxAmount,
            name: name,
            category: category
        }));
        
        // Get new path ID
        pathId = _paths.length - 1;
        
        // Add to category mapping
        _pathsByCategory[category].push(pathId);
        
        // Emit event
        emit PathAdded(pathId, tokens, dexes, name, category);
        
        return pathId;
    }
    
    /**
     * @notice Update path status
     * @param pathId The ID of the path
     * @param isActive New active status
     */
    function setPathActive(uint256 pathId, bool isActive) external override onlyOperator {
        require(pathId < _paths.length, "Invalid path ID");
        
        _paths[pathId].isActive = isActive;
        
        emit PathUpdated(pathId, isActive);
    }
    
    /**
     * @notice Get path details
     * @param pathId The ID of the path
     * @return path The arbitrage path
     */
    function getPath(uint256 pathId) external view override returns (ArbitragePath memory path) {
        require(pathId < _paths.length, "Invalid path ID");
        return _paths[pathId];
    }
    
    /**
     * @notice Get path count
     * @return The number of paths
     */
    function getPathCount() external view override returns (uint256) {
        return _paths.length;
    }
    
    /**
     * @notice Get paths by category
     * @param category The category to filter by
     * @return pathIds Array of path IDs
     */
    function getPathsByCategory(uint8 category) external view override returns (uint256[] memory pathIds) {
        return _pathsByCategory[category];
    }
    
    /**
     * @notice Update a path's maximum amount
     * @param pathId The ID of the path
     * @param maxAmount New maximum amount
     */
    function updatePathMaxAmount(uint256 pathId, uint256 maxAmount) external onlyOperator {
        require(pathId < _paths.length, "Invalid path ID");
        
        _paths[pathId].maxAmount = maxAmount;
    }
    
    /**
     * @notice Update a path's name
     * @param pathId The ID of the path
     * @param name New path name
     */
    function updatePathName(uint256 pathId, string calldata name) external onlyOperator {
        require(pathId < _paths.length, "Invalid path ID");
        
        _paths[pathId].name = name;
    }
}
