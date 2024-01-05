/*

    Copyright 2023 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0
*/

pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "D3Vault/D3Vault.sol";
import "D3Vault/periphery/D3Token.sol";
import {MakerTypes} from "contracts/DODOV3MM/lib/MakerTypes.sol";
import "mock/MockERC20.sol";
import "mock/WETH9.sol";
import "mock/MockRouter.sol";
import "mock/MockFeeRateModel.sol";
import {CloneFactory} from "contracts/DODOV3MM/lib/CloneFactory.sol";
import "D3Pool/D3MM.sol";
import {D3Maker} from "D3Pool/D3Maker.sol";
import "periphery/D3MMFactory.sol";
import "periphery/D3MMLiquidationRouter.sol";
import {MockD3UserQuota} from "mock/MockD3UserQuota.sol";
import {MockD3Pool} from "mock/MockD3Pool.sol";
import {MockChainlinkPriceFeed} from "mock/MockChainlinkPriceFeed.sol";
import {CloneFactory} from "contracts/DODOV3MM/lib/CloneFactory.sol";
import {D3PoolQuota} from "D3Vault/periphery/D3PoolQuota.sol";
import {D3Oracle, PriceSource} from "contracts/DODOV3MM/periphery/D3Oracle.sol";
import {D3Proxy} from "contracts/DODOV3MM/periphery/D3Proxy.sol";
import {D3RateManager} from "D3Vault/periphery/D3RateManager.sol";
import {LiquidationOrder} from "D3Vault/D3VaultStorage.sol";
import {DODOApprove} from "mock/DODOApprove.sol";
import {DODOApproveProxy} from "mock/DODOApproveProxy.sol";
import {MockFailD3Proxy} from "mock/MockD3Proxy.sol";
import {MockD3MM} from "mock/MockD3MM.sol";
import {MockD3MMFactory} from "mock/MockD3MMFactory.sol";
import {Errors as PoolErrors} from "contracts/DODOV3MM/lib/Errors.sol";
import {D3UserQuota} from "D3Vault/periphery/D3UserQuota.sol";

contract TestContext is Test {
    DODOApprove public dodoApprove;
    DODOApproveProxy public dodoApproveProxy;
    MockFailD3Proxy public failD3Proxy;

    D3Vault public d3Vault;
    address public owner = address(121);
    address public vaultOwner = address(122);
    address public poolCreator = address(123);
    address public maintainer = address(124);
    address public user1 = address(1111);
    address public user2 = address(2222);
    address public user3 = address(3333);
    address public liquidator = address(3333);
    address public testPool = address(99999);
    address public maker = address(8888);

    MockERC20 public token1;
    MockERC20 public token1D;

    MockERC20 public token2;
    MockERC20 public token3;
    MockERC20 public token4;
    WETH9 public weth;
    MockERC20 public wethD;
    MockERC20 public dodo;
    MockFeeRateModel public feeRateModel;

    MockChainlinkPriceFeed public token1ChainLinkOracle;
    MockChainlinkPriceFeed public token2ChainLinkOracle;
    MockChainlinkPriceFeed public token3ChainLinkOracle;
    MockChainlinkPriceFeed public token4ChainLinkOracle;
    MockChainlinkPriceFeed public sequencerUptimeFeed;

    MockRouter public router;
    D3MMLiquidationRouter public liquidationRouter;

    D3Oracle public oracle;
    D3MM public d3MMTemp;
    D3Maker public d3MakerTemp;
    MockD3MMFactory public d3MMFactory;
    MockD3MM public d3MM;
    D3Proxy public d3Proxy;
    D3Maker public d3MakerWithPool;
    D3UserQuota public d3UserQuota;

    uint256 public constant DEFAULT_MINIMUM_DTOKEN = 1000;

    function createD3MMFactory() public {
        d3MMTemp = new MockD3MM();
        d3MakerTemp = new D3Maker();
        address[] memory d3Temps = new address[](1);
        d3Temps[0] = address(d3MMTemp);
        address[] memory d3MakerTemps = new address[](1);
        d3MakerTemps[0] = address(d3MakerTemp);
        feeRateModel = new MockFeeRateModel();
        feeRateModel.init(owner, 2e14); //0.02%
        d3MMFactory = new MockD3MMFactory(
            address(this),
            d3Temps,
            d3MakerTemps,
            address(address(new CloneFactory())),
            address(d3Vault),
            address(oracle),
            address(feeRateModel),
            maintainer
        );
    }

    function createD3UserQuotaTokens() public {
        token1 = new MockERC20("Wrapped BTC", "WBTC", 8);
        token1D = new MockERC20("Wrapped BTC B", "WBTC B", 8);

        token2 = new MockERC20("Token2", "TK2", 18);
        token3 = new MockERC20("Token3", "TK3", 18);
        dodo = new MockERC20("DODO Token", "DODO", 18);
        createWETH();
        wethD = new MockERC20("WETH B", "WETH B", 18);
    }

    function createWETH() public {
        weth = new WETH9();
    }

    MockD3UserQuota public mockUserQuota;
    D3PoolQuota public poolQuota;
    D3RateManager public rateManager;

    function testSuccess() public {
        assertEq(true, true);
    }

    function createTokens() public {
        token1 = new MockERC20("Wrapped BTC", "WBTC", 8);
        token2 = new MockERC20("Token2", "TK2", 18);
        token3 = new MockERC20("Token3", "TK3", 18);
        token4 = new MockERC20("Token4", "TK4", 18);
        weth = new WETH9();
        vm.label(address(token1), "token1");
        vm.label(address(token2), "token2");
        vm.label(address(token3), "token3");
        vm.label(address(token4), "token4");
    }

    function createD3Oracle() public {
        oracle = new D3Oracle();
        token1ChainLinkOracle = new MockChainlinkPriceFeed("Token1/USD", 18);
        token2ChainLinkOracle = new MockChainlinkPriceFeed("Token2/USD", 18);
        token3ChainLinkOracle = new MockChainlinkPriceFeed("Token3/USD", 18);
        token4ChainLinkOracle = new MockChainlinkPriceFeed("WETH/USD", 18);
        sequencerUptimeFeed = new MockChainlinkPriceFeed("SequencerUptimeFeed", 1);
        token1ChainLinkOracle.feedData(1300 * 1e18);
        token2ChainLinkOracle.feedData(12 * 1e18);
        token3ChainLinkOracle.feedData(1 * 1e18);
        token4ChainLinkOracle.feedData(12 * 1e18);
        sequencerUptimeFeed.feedData(0);
        oracle.setPriceSource(
            address(token1), PriceSource(address(token1ChainLinkOracle), true, 5 * (10 ** 17), 18, 8, 3600)
        ); // don't need tokendec
        oracle.setPriceSource(
            address(token2), PriceSource(address(token2ChainLinkOracle), true, 5 * (10 ** 17), 18, 18, 3600)
        );
        oracle.setPriceSource(
            address(token3), PriceSource(address(token3ChainLinkOracle), true, 5 * (10 ** 17), 18, 18, 3600)
        );
        oracle.setPriceSource(
            address(weth), PriceSource(address(token4ChainLinkOracle), true, 5 * (10 ** 17), 18, 18, 3600)
        );
    }

    function createMockOracle() public {
        oracle = new D3Oracle();
        token1ChainLinkOracle = new MockChainlinkPriceFeed("WBTC/USD", 18);
        token2ChainLinkOracle = new MockChainlinkPriceFeed("Token2/USD", 18);
        token3ChainLinkOracle = new MockChainlinkPriceFeed("Token3/USD", 18);
        token4ChainLinkOracle = new MockChainlinkPriceFeed("WETH/USD", 18);
        token1ChainLinkOracle.feedData(26000 * 1e18);
        token2ChainLinkOracle.feedData(12 * 1e18);
        token3ChainLinkOracle.feedData(1 * 1e18);
        token4ChainLinkOracle.feedData(1800 * 1e18);
        oracle.setPriceSource(
            address(token1), PriceSource(address(token1ChainLinkOracle), true, 5 * (10 ** 17), 18, 8, 3600)
        );
        oracle.setPriceSource(
            address(token2), PriceSource(address(token2ChainLinkOracle), true, 5 * (10 ** 17), 18, 18, 3600)
        );
        oracle.setPriceSource(
            address(token3), PriceSource(address(token3ChainLinkOracle), true, 5 * (10 ** 17), 18, 18, 3600)
        );
        oracle.setPriceSource(
            address(weth), PriceSource(address(token4ChainLinkOracle), true, 5 * (10 ** 17), 18, 18, 3600)
        );
    }

    function createD3RateManager() public {
        rateManager = new D3RateManager();
        rateManager.setStableCurve(address(token1), 20e16, 1e18, 2e18, 80e16); // baseRate 20%, slope1 1, slope2 2, optimalUsage 80%
        rateManager.setStableCurve(address(token2), 20e16, 1e18, 2e18, 80e16); // baseRate 20%, slope1 1, slope2 2, optimalUsage 80%
        rateManager.setStableCurve(address(token3), 20e16, 1e18, 2e18, 80e16); // baseRate 20%, slope1 1, slope2 2, optimalUsage 80%
    }

    function createRouter() public {
        router = new MockRouter(address(oracle));
        token1.mint(address(router), 100000 ether);
        token2.mint(address(router), 100000 ether);
        token3.mint(address(router), 100000 ether);
    }

    function createLiquidatorAdapter() public {
        liquidationRouter = new D3MMLiquidationRouter(address(dodoApprove));
        vm.label(address(liquidationRouter), "liquidationRouter");
    }

    function createD3VaultTwo() public {
        poolQuota = new D3PoolQuota();
        d3Vault = new D3Vault();
        dodo = new MockERC20("DODO Token", "DODO", 18);
        d3UserQuota = new D3UserQuota(address(dodo),address(d3Vault));
        vm.label(address(d3Vault), "d3Vault");
        d3Vault.transferOwnership(vaultOwner);

        vm.startPrank(vaultOwner);

        d3Vault.setCloneFactory(address(new CloneFactory()));
        d3Vault.setDTokenTemplate(address(new D3Token()));
        d3Vault.setNewOracle(address(oracle));
        d3Vault.setNewD3UserQuota(address(d3UserQuota));
        d3Vault.setNewD3PoolQuota(address(poolQuota));
        d3Vault.setNewRateManager(address(rateManager));
        d3Vault.setMaintainer(maintainer);

        d3Vault.setIM(40e16);
        d3Vault.setMM(20e16);

        d3Vault.addNewToken(
            address(token1), // token
            1000 * 1e8, // max deposit
            100 * 1e8, // max collateral
            80 * 1e16, // collateral weight: 80%
            120 * 1e16, // debtWeight: 120%
            20 * 1e16 // reserve factor: 20%
        );

        d3Vault.addNewToken(
            address(token2), // token
            1000 * 1e18, // max deposit
            500 * 1e18, // max collateral
            90 * 1e16, // collateral weight: 90%
            110 * 1e16, // debtWeight: 110%
            10 * 1e16 // reserve factor: 10%
        );

        d3Vault.addNewToken(
            address(token3), // token
            1000 * 1e18, // max deposit
            500 * 1e18, // max collateral
            90 * 1e16, // collateral weight: 90%
            110 * 1e16, // debtWeight: 110%
            10 * 1e16 // reserve factor: 10%
        );

        vm.stopPrank();
    }

    function createD3Vault() public {
        mockUserQuota = new MockD3UserQuota();
        poolQuota = new D3PoolQuota();

        d3Vault = new D3Vault();
        vm.label(address(d3Vault), "d3Vault");
        d3Vault.transferOwnership(vaultOwner);

        vm.startPrank(vaultOwner);

        d3Vault.setCloneFactory(address(new CloneFactory()));
        d3Vault.setDTokenTemplate(address(new D3Token()));
        d3Vault.setNewOracle(address(oracle));
        d3Vault.setNewD3UserQuota(address(mockUserQuota));
        d3Vault.setNewD3PoolQuota(address(poolQuota));
        d3Vault.setNewRateManager(address(rateManager));
        d3Vault.setMaintainer(maintainer);

        d3Vault.setIM(40e16);
        d3Vault.setMM(20e16);

        d3Vault.addNewToken(
            address(token1), // token
            1000 * 1e8, // max deposit
            100 * 1e8, // max collateral
            80 * 1e16, // collateral weight: 80%
            120 * 1e16, // debtWeight: 120%
            20 * 1e16 // reserve factor: 20%
        );

        d3Vault.addNewToken(
            address(token2), // token
            1000 * 1e18, // max deposit
            500 * 1e18, // max collateral
            90 * 1e16, // collateral weight: 90%
            110 * 1e16, // debtWeight: 110%
            10 * 1e16 // reserve factor: 10%
        );

        d3Vault.addNewToken(
            address(token3), // token
            1000 * 1e18, // max deposit
            500 * 1e18, // max collateral
            90 * 1e16, // collateral weight: 90%
            110 * 1e16, // debtWeight: 110%
            10 * 1e16 // reserve factor: 10%
        );

        vm.stopPrank();
    }

    function createD3MM() public {
        d3MM = MockD3MM(d3MMFactory.breedD3Pool(poolCreator, maker, 100000, 0));
        vm.label(address(d3MM), "d3MM");

        poolMakerSetAllTokenInfo();
        bool available = d3Vault.allPoolAddrMap(address(d3MM));
        assertEq(available, true);
    }

    function createD3Proxy() public {
        dodoApprove = new DODOApprove();
        dodoApproveProxy = new DODOApproveProxy(address(dodoApprove));
        dodoApprove.init(poolCreator, address(dodoApproveProxy));

        d3Proxy = new D3Proxy(
            address(dodoApproveProxy),
            address(weth),
            address(d3Vault)
        );
        failD3Proxy = new MockFailD3Proxy(
            address(dodoApproveProxy),
            address(weth)
        );

        address[] memory proxies = new address[](2);
        proxies[0] = address(d3Proxy);
        proxies[1] = address(failD3Proxy);
        dodoApproveProxy.init(poolCreator, proxies);
    }

    function contextBasic() public {
        createTokens();
        createD3Oracle();
        createD3RateManager();
        createD3Vault();
        createD3MMFactory();
        createD3Proxy();

        vm.prank(vaultOwner);
        d3Vault.setNewD3Factory(address(d3MMFactory));
        createD3MM();
        
        createRouter();
        createLiquidatorAdapter();
        vm.prank(vaultOwner);
        d3Vault.addRouter(address(liquidationRouter));
    }

    // ---------- helper ----------

    function faucetToken(address token, address to, uint256 amount) public {
        MockERC20(token).mint(to, amount);
    }

    function faucetWeth(address to, uint256 amount) public {
        vm.deal(address(this), amount);
        weth.deposit{value: amount}();
        weth.transfer(to, amount);
    }

    function userDeposit(address user, address token, uint256 amount) public {
        vm.prank(user);
        d3Proxy.userDeposit(user, token, amount, 0);
    }

    function userWithdraw(address user, address token, uint256 dTokenAmount) public {
        vm.prank(user);
        d3Vault.userWithdraw(user, user, token, dTokenAmount);
    }

    function poolBorrow(address pool, address token, uint256 amount) public {
        vm.prank(poolCreator);
        D3MM(pool).borrow(token, amount);
    }

    function poolRepay(address pool, address token, uint256 amount) public {
        vm.prank(pool);
        d3Vault.poolRepay(token, amount);
    }

    function liquidateSwap(
        address pool,
        address fromToken,
        address toToken,
        uint256 fromAmount
    ) public {
        LiquidationOrder memory order = LiquidationOrder(
            fromToken,
            toToken,
            fromAmount
        );
        bytes memory realRouteData = abi.encodeWithSignature(
            "swap(address,address,uint256)",
            fromToken,
            toToken,
            fromAmount
        );
        bytes memory routeData = abi.encodeWithSignature(
            "D3Callee((address,address,uint256),address,bytes)",
            order,
            address(router),
            realRouteData
        );
        vm.prank(liquidator);
        d3Vault.liquidateByDODO(pool, order, routeData, address(liquidationRouter));
    }

    function logCollateralRatio(address pool) public view {
        uint256 collateralRatio = d3Vault.getCollateralRatio(pool);
        console.log("collateralRatio", collateralRatio / 1e16, "%");

        uint256 collateralRatioBorrow = d3Vault.getCollateralRatioBorrow(pool);
        console.log("collateralRatioBorrow", collateralRatioBorrow / 1e16, "%");

        console.log("");
    }

    function logAssetInfo(address token) public view {
        (
            address dToken,
            uint256 totalBorrows,
            uint256 totalReserves,
            uint256 reserveFactor,
            uint256 borrowIndex,
            uint256 accrualTime,
            uint256 maxDepositAmount,
            uint256 collateralWeight,
            uint256 debtWeight,
            uint256 withdrawnReserves,
            uint256 balance
        ) = d3Vault.getAssetInfo(token);

        console.log("dToken", dToken);
        console.log("balance", balance);
        console.log("totalBorrows", totalBorrows);
        console.log("totalReserves", totalReserves);
        console.log("reserveFactor", reserveFactor);
        console.log("borrowIndex", borrowIndex);
        console.log("accrualTime", accrualTime);
        console.log("maxDepositAmount", maxDepositAmount);
        console.log("collateralWeight", collateralWeight);
        console.log("debtWeight", debtWeight);
        console.log("withdrawnReserves", withdrawnReserves);
        console.log("");
    }

    // ----------- pool helper -----------
    function stickOneSlot(
        uint256 numberA,
        uint256 numberADecimal,
        uint256 numberB,
        uint256 numberBDecimal
    ) public pure returns (uint256 numberSet) {
        numberSet = (numberA << 32) + (numberADecimal << 24) + (numberB << 8) + numberBDecimal;
    }

    function stickAmount(
        uint256 askAmount,
        uint256 askAmountDecimal,
        uint256 bidAmount,
        uint256 bidAmountDecimal
    ) public pure returns (uint64 amountSet) {
        amountSet = uint64(stickOneSlot(askAmount, askAmountDecimal, bidAmount, bidAmountDecimal));
    }

    function stickPrice(
        uint256 midPrice,
        uint256 midPriceDecimal,
        uint256 feeRate,
        uint256 askUpRate,
        uint256 bidDownRate
    ) public pure returns(uint80 priceInfo) {
        priceInfo = uint80(
            (midPrice << 56) + (midPriceDecimal << 48) + (feeRate << 32) + (askUpRate << 16) + bidDownRate
        );
    }

    function stickKs(uint256 kAsk, uint256 kBid)
        public
        pure
        returns (uint32 kSet)
    {
        kSet = uint32((kAsk << 16) + kBid);
    }

    function contructToken1MMInfo() public pure returns(MakerTypes.TokenMMInfoWithoutCum memory tokenInfo) {
        tokenInfo.priceInfo = stickPrice(1300, 18, 6, 12, 10);
        tokenInfo.amountInfo = stickAmount(30, 18, 30, 18);
        tokenInfo.kAsk = tokenInfo.kBid = 1000;
        //tokenInfo.decimal = 18;
    }

    function contructToken1Dec8MMInfo() public pure returns(MakerTypes.TokenMMInfoWithoutCum memory tokenInfo) {
        tokenInfo.priceInfo = stickPrice(1300, 18, 6, 12, 10);
        tokenInfo.amountInfo = stickAmount(30, 18, 300, 18); // don't need token dec
        tokenInfo.kAsk = tokenInfo.kBid = 1000;
        //tokenInfo.decimal = 18;
    }

    function contructBTCMMInfo() public pure returns(MakerTypes.TokenMMInfoWithoutCum memory tokenInfo) {
        tokenInfo.priceInfo = stickPrice(26000, 18, 6, 12, 10);
        tokenInfo.amountInfo = stickAmount(30, 18, 3000, 18); // don't need token dec
        tokenInfo.kAsk = tokenInfo.kBid = 1000;
        //tokenInfo.decimal = 8;
    }

    function contructToken2MMInfo() public pure returns(MakerTypes.TokenMMInfoWithoutCum memory tokenInfo) {
        tokenInfo.priceInfo = stickPrice(12, 18, 6, 23, 15);
        tokenInfo.amountInfo = stickAmount(30, 18, 30, 18);
        tokenInfo.kAsk = tokenInfo.kBid = 1000;
        //tokenInfo.decimal = 18;
    }

    function contructToken3MMInfo() public pure returns(MakerTypes.TokenMMInfoWithoutCum memory tokenInfo) {
        tokenInfo.priceInfo = stickPrice(1, 18, 6, 12, 10);
        tokenInfo.amountInfo = stickAmount(300, 18, 300, 18);
        tokenInfo.kAsk = tokenInfo.kBid = 1000;
        //tokenInfo.decimal = 18;
    }

    function contructToken4MMInfo() public pure returns(MakerTypes.TokenMMInfoWithoutCum memory tokenInfo) {
        tokenInfo.priceInfo = stickPrice(12, 18, 6, 20, 14);
        tokenInfo.amountInfo = stickAmount(300, 18, 300, 18);
        tokenInfo.kAsk = tokenInfo.kBid = 1000;
        //tokenInfo.decimal = 18;
    }

    function poolMakerSetAllTokenInfo() public {
        ( , ,address poolMaker, , ) = d3MM.getD3MMInfo();
        d3MakerWithPool = D3Maker(poolMaker);
        // set token price
        MakerTypes.TokenMMInfoWithoutCum memory token1Info = contructToken1Dec8MMInfo();
        MakerTypes.TokenMMInfoWithoutCum memory token2Info = contructToken2MMInfo();
        MakerTypes.TokenMMInfoWithoutCum memory token3Info = contructToken3MMInfo();
        vm.startPrank(maker);
        d3MakerWithPool.setNewToken(address(token1), true, token1Info.priceInfo, token1Info.amountInfo, token1Info.kAsk, token1Info.kBid);
        d3MakerWithPool.setNewToken(address(token2), true, token2Info.priceInfo, token2Info.amountInfo, token2Info.kAsk, token2Info.kBid);
        d3MakerWithPool.setNewToken(address(token3), true, token3Info.priceInfo, token3Info.amountInfo, token3Info.kAsk, token3Info.kBid);
        d3MakerWithPool.setNewToken(address(weth), true, token2Info.priceInfo, token2Info.amountInfo, token2Info.kAsk, token2Info.kBid);
        vm.stopPrank();
    }

    function setVaultAsset() public {
        token1.mint(user1, 1000 * 1e8);
        vm.prank(user1);
        token1.approve(address(dodoApprove), type(uint256).max);
        token2.mint(user1, 1000 * 1e18);
        vm.prank(user1);
        token2.approve(address(dodoApprove), type(uint256).max);
        token3.mint(user1, 1000 * 1e18);
        vm.prank(user1);
        token3.approve(address(dodoApprove), type(uint256).max);

        mockUserQuota.setUserQuota(user1, address(token1), 1000 * 1e8);
        userDeposit(user1, address(token1), 500 * 1e8);
        mockUserQuota.setUserQuota(user1, address(token2), 1000 * 1e18);
        userDeposit(user1, address(token2), 500 * 1e18);
        mockUserQuota.setUserQuota(user1, address(token3), 1000 * 1e18);
        userDeposit(user1, address(token3), 500 * 1e18);
        mockUserQuota.setUserQuota(user1, address(weth), 1000 * 1e18);
    }

    function mintPoolCreator() public {
        token1.mint(poolCreator, 1000 * 1e8);
        token2.mint(poolCreator, 1000 * 1e18);
        token3.mint(poolCreator, 1000 * 1e18);
        vm.startPrank(poolCreator);
        token1.approve(address(d3Vault), type(uint256).max);
        token1.approve(address(dodoApprove), type(uint256).max);
        token3.approve(address(d3Vault), type(uint256).max);
        token3.approve(address(dodoApprove), type(uint256).max);
        token2.approve(address(d3Vault), type(uint256).max);
        token2.approve(address(dodoApprove), type(uint256).max);
        vm.stopPrank();
    }

    function setPoolAsset() public {
        token1.mint(address(d3MM), 100 * 1e8);
        token2.mint(address(d3MM), 100 * 1e18);
        token3.mint(address(d3MM), 100 * 1e18);
        vm.startPrank(poolCreator);
        d3MM.makerDeposit(address(token1));
        d3MM.makerDeposit(address(token2));
        d3MM.makerDeposit(address(token3));
        vm.stopPrank();
    }

}
