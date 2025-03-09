// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./AccessManager.sol";
import "./MetaTxRouter.sol";
import "./PathRegistry.sol";
import "./DEXAdapter.sol";
import "./FlashLoanProvider.sol";
import "./PriceOracle.sol";
import "./ProfitabilityAnalyzer.sol";
import "./ArbitrageController.sol";
import "./Settings.sol";
import "./StrategyRegistry.sol";
import "./LiquidityRegistry.sol";

/**
 * @title SystemDeployer
 * @notice Deploys and configures the entire meta-arbitrage system
 * @dev Used as a deployment script for coordinated system setup
 */
contract SystemDeployer {
    // Deployed contract addresses
    AccessManager public accessManager;
    MetaTxRouter public metaTxRouter;
    PathRegistry public pathRegistry;
    DEXAdapter public dexAdapter;
    FlashLoanProvider public flashLoanProvider;
    PriceOracle public priceOracle;
    ProfitabilityAnalyzer public profitabilityAnalyzer;
    ArbitrageController public arbitrageController;
    Settings public settings;
    StrategyRegistry public strategyRegistry;
    LiquidityRegistry public liquidityRegistry;
    
    // External protocol addresses on Arbitrum
    address public constant AAVE_POOL = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address public constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address public constant DODO_APPROVE = 0xA867241cDC8d3b0C07C85cC06F25a0cD3b5474d8;
    address public constant UNISWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address public constant SUSHISWAP_ROUTER = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;
    address public constant CAMELOT_ROUTER = 0xc873fEcbd354f5A56E00E710B90EF4201db2448d;
    
    // Token addresses on Arbitrum
    address public constant USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address public constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public constant DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
    address public constant WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    
    // Events
    event SystemDeployed(
        address accessManager,
        address metaTxRouter,
        address arbitrageController
    );
    
    /**
     * @notice Deploy the entire arbitrage system
     */
    function deploySystem() external {
        // Deploy core contracts
        accessManager = new AccessManager();
        settings = new Settings(address(accessManager));
        
        // Deploy router after access manager
        metaTxRouter = new MetaTxRouter(address(accessManager));
        
        // Configure meta-tx router in access manager
        accessManager.setMetaTxRouter(address(metaTxRouter));
        
        // Deploy component contracts
        pathRegistry = new PathRegistry(address(accessManager));
        dexAdapter = new DEXAdapter(
            address(accessManager),
            UNISWAP_ROUTER,
            SUSHISWAP_ROUTER,
            CAMELOT_ROUTER,
            BALANCER_VAULT
        );
        flashLoanProvider = new FlashLoanProvider(
            address(accessManager),
            AAVE_POOL,
            BALANCER_VAULT,
            DODO_APPROVE
        );
        priceOracle = new PriceOracle(
            address(accessManager),
            USDC,
            WETH
        );
        profitabilityAnalyzer = new ProfitabilityAnalyzer(address(accessManager));
        strategyRegistry = new StrategyRegistry(address(accessManager));
        liquidityRegistry = new LiquidityRegistry(address(accessManager));
        
        // Deploy controller last
        arbitrageController = new ArbitrageController(address(accessManager));
        
        // Configure meta-tx routers in all contracts
        pathRegistry.setMetaTxRouter(address(metaTxRouter));
        dexAdapter.setMetaTxRouter(address(metaTxRouter));
        flashLoanProvider.setMetaTxRouter(address(metaTxRouter));
        priceOracle.setMetaTxRouter(address(metaTxRouter));
        profitabilityAnalyzer.setMetaTxRouter(address(metaTxRouter));
        arbitrageController.setMetaTxRouter(address(metaTxRouter));
        strategyRegistry.setMetaTxRouter(address(metaTxRouter));
        liquidityRegistry.setMetaTxRouter(address(metaTxRouter));
        settings.setMetaTxRouter(address(metaTxRouter));
        
        // Set up dependencies
        flashLoanProvider.setDependencies(
            address(dexAdapter),
            address(pathRegistry)
        );
        
        priceOracle.setDependencies(address(dexAdapter));
        
        profitabilityAnalyzer.setDependencies(
            address(pathRegistry),
            address(dexAdapter),
            address(flashLoanProvider),
            address(settings),
            address(priceOracle)
        );
        
        arbitrageController.setDependencies(
            address(pathRegistry),
            address(flashLoanProvider),
            address(profitabilityAnalyzer),
            address(settings),
            address(strategyRegistry)
        );
        
        // Configure default settings
        settings.setDefaultMinProfitBps(150); // 1.5% minimum profit
        settings.setDefaultFlashLoanProvider(0); // AAVE as default
        settings.setGasPriceTarget(1000000000); // 1 gwei
        
        // Emit deployment event
        emit SystemDeployed(
            address(accessManager),
            address(metaTxRouter),
            address(arbitrageController)
        );
    }
    
    /**
     * @notice Add common arbitrage paths
     */
    function addCommonPaths() external {
        require(address(pathRegistry) != address(0), "System not deployed");
        
        // Common token swap paths
        
        // USDC -> WETH -> USDC Triangle (Uniswap V3)
        address[] memory tokens1 = new address[](3);
        tokens1[0] = USDC;
        tokens1[1] = WETH;
        tokens1[2] = USDC;
        
        uint8[] memory dexes1 = new uint8[](2);
        dexes1[0] = 0; // UNISWAP
        dexes1[1] = 0; // UNISWAP
        
        uint24[] memory poolFees1 = new uint24[](2);
        poolFees1[0] = 500; // 0.05% fee
        poolFees1[1] = 500; // 0.05% fee
        
        pathRegistry.addPath(
            tokens1,
            dexes1,
            poolFees1,
            1000000 * 10**6, // 1M USDC max
            "USDC-WETH-USDC (Uniswap)",
            1 // Category 1: Stablecoins
        );
        
        // USDC -> WETH -> USDC Cross-DEX
        uint8[] memory dexes2 = new uint8[](2);
        dexes2[0] = 0; // UNISWAP
        dexes2[1] = 1; // SUSHISWAP
        
        pathRegistry.addPath(
            tokens1,
            dexes2,
            poolFees1,
            1000000 * 10**6, // 1M USDC max
            "USDC-WETH-USDC (Uni-Sushi)",
            1 // Category 1: Stablecoins
        );
        
        // WETH -> WBTC -> WETH Triangle
        address[] memory tokens2 = new address[](3);
        tokens2[0] = WETH;
        tokens2[1] = WBTC;
        tokens2[2] = WETH;
        
        uint8[] memory dexes3 = new uint8[](2);
        dexes3[0] = 0; // UNISWAP
        dexes3[1] = 2; // CAMELOT
        
        uint24[] memory poolFees2 = new uint24[](2);
        poolFees2[0] = 3000; // 0.3% fee
        poolFees2[1] = 3000; // 0.3% fee
        
        pathRegistry.addPath(
            tokens2,
            dexes3,
            poolFees2,
            1000 * 10**18, // 1,000 WETH max
            "WETH-WBTC-WETH (Uni-Camelot)",
            2 // Category 2: Blue chips
        );
        
        // USDC -> DAI -> USDC Stablecoin Triangle
        address[] memory tokens3 = new address[](3);
        tokens3[0] = USDC;
        tokens3[1] = DAI;
        tokens3[2] = USDC;
        
        uint8[] memory dexes4 = new uint8[](2);
        dexes4[0] = 0; // UNISWAP
        dexes4[1] = 3; // BALANCER
        
        uint24[] memory poolFees3 = new uint24[](2);
        poolFees3[0] = 100; // 0.01% fee
        poolFees3[1] = 100; // 0.01% fee for Balancer
        
        pathRegistry.addPath(
            tokens3,
            dexes4,
            poolFees3,
            5000000 * 10**6, // 5M USDC max
            "USDC-DAI-USDC (Uni-Balancer)",
            1 // Category 1: Stablecoins
        );
        
        // 4-token path: USDC -> WETH -> WBTC -> USDC
        address[] memory tokens4 = new address[](4);
        tokens4[0] = USDC;
        tokens4[1] = WETH;
        tokens4[2] = WBTC;
        tokens4[3] = USDC;
        
        uint8[] memory dexes5 = new uint8[](3);
        dexes5[0] = 0; // UNISWAP
        dexes5[1] = 2; // CAMELOT
        dexes5[2] = 0; // UNISWAP
        
        uint24[] memory poolFees4 = new uint24[](3);
        poolFees4[0] = 500; // 0.05% fee
        poolFees4[1] = 3000; // 0.3% fee
        poolFees4[2] = 500; // 0.05% fee
        
        pathRegistry.addPath(
            tokens4,
            dexes5,
            poolFees4,
            500000 * 10**6, // 500k USDC max
            "USDC-WETH-WBTC-USDC (Multi-DEX)",
            3 // Category 3: Complex
        );
    }
    
    /**
     * @notice Add common strategies
     */
    function addCommonStrategies() external {
        require(address(strategyRegistry) != address(0), "System not deployed");
        
        // Add paths first if not already added
        if (pathRegistry.getPathCount() == 0) {
            this.addCommonPaths();
        }
        
        // Stablecoin strategy (paths with category 1)
        uint256[] memory stablePaths = pathRegistry.getPathsByCategory(1);
        
        strategyRegistry.addStrategy(
            "Stablecoin Arbitrage",
            stablePaths,
            0, // AAVE
            150, // 1.5% min profit
            3000000, // 3M gas
            300 // 5 min interval
        );
        
        // Blue chip strategy (paths with category 2)
        uint256[] memory bluechipPaths = pathRegistry.getPathsByCategory(2);
        
        strategyRegistry.addStrategy(
            "Blue Chip Arbitrage",
            bluechipPaths,
            0, // AAVE
            200, // 2% min profit
            4000000, // 4M gas
            600 // 10 min interval
        );
        
        // Complex strategy (paths with category 3)
        uint256[] memory complexPaths = pathRegistry.getPathsByCategory(3);
        
        strategyRegistry.addStrategy(
            "Complex Multi-hop Arbitrage",
            complexPaths,
            0, // AAVE
            300, // 3% min profit
            5000000, // 5M gas
            1800 // 30 min interval
        );
        
        // Cross-DEX strategy (all paths)
        uint256[] memory allPaths = new uint256[](pathRegistry.getPathCount());
        for (uint256 i = 0; i < pathRegistry.getPathCount(); i++) {
            allPaths[i] = i;
        }
        
        strategyRegistry.addStrategy(
            "All Opportunities",
            allPaths,
            0, // AAVE
            100, // 1% min profit
            3000000, // 3M gas
            60 // 1 min interval
        );
    }
}