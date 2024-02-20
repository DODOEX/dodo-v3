// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "../lib/DecimalMath.sol";
import "./Errors.sol";

struct LiquidationOrder {
    address fromToken;
    address toToken;
    uint256 fromAmount;
}

contract D3VaultStorage is ReentrancyGuard, Ownable {
    address public _D3_FACTORY_;
    address public _D3TOKEN_LOGIC_;
    address public _CLONE_FACTORY_;
    address public _USER_QUOTA_;
    address public _POOL_QUOTA_;
    address public _ORACLE_;
    address public _RATE_MANAGER_;
    address public _MAINTAINER_;
    address public _PENDING_REMOVE_POOL_;
    address[] public tokenList;
    uint256 public IM; // 1e18 = 100%
    uint256 public MM; // 1e18 = 100%
    uint256 public DISCOUNT = 95e16; // 95%
    uint256 public borrowerCount;
    uint256 internal constant SECONDS_PER_YEAR = 31536000;
    uint256 internal constant DEFAULT_MINIMUM_DTOKEN = 1000;

    mapping(address => uint256) public accrualTimestampMap;
    mapping(address => bool) public allPoolAddrMap;
    mapping(address => address[]) public creatorPoolMap; // user => pool[]
    mapping(address => bool) public tokens;
    mapping(address => AssetInfo) public assetInfo;
    mapping(address => bool) public allowedRouter;
    mapping(address => bool) public allowedLiquidator;
    mapping(address => mapping(address => uint256)) public liquidationTarget; // pool => (token => amount)

    struct AssetInfo {
        address dToken;
        uint256 balance;
        // borrow info
        uint256 totalBorrows;
        uint256 borrowIndex;
        uint256 accrualTime;
        // reserve info
        uint256 totalReserves;
        uint256 withdrawnReserves;
        uint256 reserveFactor;
        // other info
        uint256 maxDepositAmount;
        uint256 maxCollateralAmount; // the max amount of token that a pool can use as collateral
        uint256 collateralWeight; // 1e18 = 100%; collateralWeight < 1e18
        uint256 debtWeight; // 1e18 = 100%; debtWeight > 1e18
        mapping(address => BorrowRecord) borrowRecord; // pool address => BorrowRecord
    }

    struct BorrowRecord {
        uint256 amount;
        uint256 interestIndex;
    }

    event PoolBorrow(address indexed pool, address indexed token, uint256 amount, uint256 interests);
    event PoolRepay(address indexed pool, address indexed token, uint256 amount, uint256 interests);
    event UserDeposit(address indexed user, address indexed token, uint256 amount, uint256 dTokenAmount);
    event UserWithdraw(address indexed msgSender, address indexed user, address indexed token, uint256 amount, uint256 dTokenAmount);
    event AddPool(address pool);
    event RemovePool(address pool);

    event SetCloneFactory(address cloneFactory);
    event SetD3Factory(address factory);
    event SetD3UserQuota(address userQuota);
    event SetD3PoolQuota(address poolQuota);
    event SetOracle(address oracle);
    event SetRateManager(address rateManager);
    event SetMaintainer(address maintainer);
    event SetIM(uint256 IM);
    event SetMM(uint256 MM);
    event SetDiscount(uint256 discount);
    event SetDTokenTemplate(address template);
    
    event AddRouter(address router);
    event RemoveRouter(address router);
    
    event AddLiquidator(address liquidator);
    event RemoveLiquidator(address liquidator);
    
    event AddToken(address token);
    event SetToken(address token);

    event Liquidate(address indexed pool, address indexed collateral, uint256 collateralAmount, address indexed debt, uint256 debtAmount);
    event StartLiquidation(address pool);
    event FinishLiquidation(address pool);

    event WithdrawReserves(address indexed token, uint256 amount);

    modifier onlyLiquidator() {
        if (!allowedLiquidator[msg.sender]) revert Errors.D3VaultNotAllowedLiquidator();
        _;
    }

    modifier onlyRouter(address router) {
        if (!allowedRouter[router]) revert Errors.D3VaultNotAllowedRouter();
        _;
    }

    modifier onlyPool() {
        if (!allPoolAddrMap[msg.sender]) revert Errors.D3VaultNotD3Pool();
        _;
    }

    modifier allowedToken(address token) {
        if (!tokens[token]) revert Errors.D3VaultNotAllowedToken();
        _;
    }

    modifier onlyFactory() {
        if (msg.sender != _D3_FACTORY_) revert Errors.D3VaultNotD3Factory();
        _;
    }

    modifier onlyRemovingPool() {
        if (msg.sender != _PENDING_REMOVE_POOL_) revert Errors.D3VaultNotPendingRemovePool();
        _;
    }
}
