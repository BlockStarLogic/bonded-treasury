// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.30;

enum FundVaultStatus {OPEN, IN_MARKET, DAMAGED, FROZEN, CLOSED}

struct Fund { 
    uint256 id; 
    string name; 
    uint256 amount; 
    address erc20; 
    address owner; 
    uint256 productId; 
    address vault;
    uint256 productIndex; 
    uint256 coverage; 
    uint256 consumptionIndex;
    uint256 createdDate; 
    uint256 closedDate; 
}

struct Fee {
    string name; 
    uint256 amount; 
    address erc20; 
    bool isPercentage; 
}

enum ProductStatus {AVAILABLE, FROZEN, CANCELLED, SOLDOUT, EXPIRED}

enum Risk {HIGH, MEDIUM, LOW}

struct Product {
    uint256 id; 
    string name; 
    address owner; 
    uint256 bondId; 
    address erc20; 
    Risk risk; 
    bool bansAllowed; 
    Range investmentPrincipal; 
    Range yield;
    Period payoutInterval; 
    Range term; 
    uint256 inventory; 
    uint256 expiryDate; 
    ProductStatus status; 
    uint256 treasurerFee; 
    uint256 purchaseFee; 
}

struct ProtoProduct {
    string name; 
    uint256 bondId; 
    Risk risk; 
    bool bansAllowed;
    Range investmentPrincipal; 
    Range yield;
    Period payoutInterval; 
    Range term; 
    uint256 inventory; 
    uint256 treasurerFee; 
    uint256 purchaseFee; 
}



enum BondStatus {ACTIVE, DELINQUENT, FROZEN, SETTLED}

enum Period {DAY, WEEK, MONTH, QUARTER, HALF, YEAR}

enum BondType {PRODUCT, TREASURER, MARKET}

struct Range { 
    uint256 max; 
    uint256 min; 
}

struct Bond { 
    uint256 id; 
    string name; 
    uint256 amount; 
    address erc20; 
    uint256 createDate;
    address owner;  
    Range consumptionPerUser; 
    uint256 residual; 
    uint256 coverage; 
    uint256 lostCoverage; 
    BondStatus status; 
    address vault;
    BondType bondType; 
}

struct BondSettlement {
    uint256 id; 
    uint256 bondId; 
    uint256 amount; 
    address consumer; 
    address executor; 
    uint256 settlementDate;
    BondSettlementStatus status; 
}

enum BondSettlementStatus {COMPLETE, DEFICIENT}

enum CoverageStatus {CONSUMED, RELEASED, SPENT}

event COVERAGE_EVENT (uint256 _bondId, uint256 _consumptionIdex, uint256 _coverage, address _consumer, CoverageStatus _status); 

event TOP_UP_EVENT (uint256 _bondId, uint256 _amount, uint256 _residual, uint256 _topUp, address _executor, BondStatus _status);

event BOND_EVENT (uint256 _bondId, uint256 _balance, address _owner, BondStatus _status); 

event COMPENSATION_EVENT (uint256 _bondId, uint256 _consumptionIndex, address _erc20, uint256 _amount, uint256 _timestamp);

enum TreasurerStatus {PERMITTED, EMBARGOED, BANNED, CANCELLED}

struct BanRequest{
    uint256 id; 
    uint256 productId; 
    uint256 fundId; 
    address member;
    address erc20; 
    uint256 expected; 
    uint256 actual;
    uint256 createDate; 
    uint256 removeDate; 
}

struct Membership {
    uint256 id; 
    address member; 
    uint256 productId; 
    TreasurerStatus status; 
}

struct Position { 
    uint256 id; 
    uint256 marketId; 
    uint256 amount; 
    address owner; 
    address treasurer; 
    uint256 openDate; 
    uint256 closeDate; 
}

enum MarketSettlementStatus {DAMAGED, CLOSED} 

struct MarketSettlement {
    uint256 id; 
    uint256 positionId; 
    uint256 amount; 
    MarketSettlementStatus status;
    uint256 settlementDate; 
}

enum VehicleType {UNISWAP, ONE_INCH, DYDX, PANCAKE}

enum MarketType {TOKEN, POOL, RWA}

enum MarketStatus {OPEN, SUSPENDED, CLOSED}

struct Market { 
    uint256 id; 
    address owner;
    MarketType mType; 
    uint256 bondId; 
    Risk risk; 
    Range yield;
    Range lossTolerance;
    Range principal; 
    address inputErc20; 
    address vehicle;
    VehicleType vType;
    Range term; 
    uint256 slots; 
    MarketStatus status;
    uint256 created; 
    uint256 expired;
}

struct ProtoMarket { 
    address owner;
    MarketType mType; 
    uint256 bondId; 
    Risk risk; 
    Range yield;
    Range lossTolerance;
    Range principal; 
    address inputErc20; 
    address vehicle;
    VehicleType vType;
    Range term; 
    uint256 slots; 
}


struct ProtoInvestment { 
    uint256 fundId; 
    uint256 marketId; 
    uint256 bondId; 
}

struct Investment { 
    uint256 id; 
    uint256 fundId; 
    uint256 marketId; 
    uint256 positionId; 
    uint256 amount;
    uint256 minimumExpectedReturn; 
    uint256 bondId; 
    uint256 coverage; 
    uint256 coverageConsumptionIndex;
    address treasurer; 
    address owner; 
    uint256 createDate;
    uint256 divestmentDate;  
}

struct Divestment { 
    uint256 id; 
    uint256 investmentId; 
    uint256 actualReturn; 
    uint256 createDate; 
}

struct Times {
    uint256 lastPull; 
    uint256 lastPush; 
    uint256 nextPull;
}