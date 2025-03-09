// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title IPathRegistry
 * @notice Interface for managing arbitrage paths
 */
interface IPathRegistry {
    /**
     * @notice Arbitrage path structure
     */
    struct ArbitragePath {
        address[] tokens;
        uint8[] dexes;
        uint24[] poolFees;
        bool isActive;
        uint256 maxAmount;
        string name;
        uint8 category;
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
    ) external returns (uint256 pathId);
    
    /**
     * @notice Update path status
     * @param pathId The ID of the path
     * @param isActive New active status
     */
    function setPathActive(uint256 pathId, bool isActive) external;
    
    /**
     * @notice Get path details
     * @param pathId The ID of the path
     * @return path The arbitrage path
     */
    function getPath(uint256 pathId) external view returns (ArbitragePath memory path);
    
    /**
     * @notice Get path count
     * @return The number of paths
     */
    function getPathCount() external view returns (uint256);
    
    /**
     * @notice Get paths by category
     * @param category The category to filter by
     * @return pathIds Array of path IDs
     */
    function getPathsByCategory(uint8 category) external view returns (uint256[] memory pathIds);
    
    /**
     * @notice Update path's maximum amount
     * @param pathId The ID of the path
     * @param maxAmount New maximum amount
     */
    function updatePathMaxAmount(uint256 pathId, uint256 maxAmount) external;
    
    /**
     * @notice Update path's name
     * @param pathId The ID of the path
     * @param name New path name
     */
    function updatePathName(uint256 pathId, string calldata name) external;
    
    /**
     * @notice Set the meta-transaction router
     * @param _metaTxRouter Address of the meta-transaction router
     */
    function setMetaTxRouter(address _metaTxRouter) external;
}