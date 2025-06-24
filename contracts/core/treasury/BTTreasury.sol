// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.30;

import "../../interfaces/treasury/IBTTreasury.sol"; 

import "../../interfaces/bond/IBTBondManager.sol";

import "../../interfaces/fund/IBTFundManager.sol"; 
import "../../interfaces/fund/IBTFundVault.sol";

import "../../interfaces/market/IBTMarketManager.sol";
import "../../interfaces/market/IBTMarket.sol"; 

import "../../interfaces/product/IBTProductManager.sol"; 

import "../../interfaces/fee/IBTFeeManager.sol"; 

import "../../interfaces/util/IBTVersion.sol";
import "../../interfaces/util/IBTRegister.sol"; 
import "../../interfaces/util/IBTIndex.sol"; 

import "../../lib/LBTLib.sol"; 

import {ProductStatus, MarketSettlementStatus, BondSettlementStatus, COMPENSATION_EVENT} from "../../structs/BTStructs.sol"; 

import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; 

contract BTTreasury is IBTVersion, IBTTreasury { 

    string constant name = "RESERVED_BT_TREASURY"; 
    uint256 constant version = 1; 

    address constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE; 

    string constant REGISTER_CA = "RESERVED_BT_REGISTER"; 
    string constant INDEX_CA = "RESERVED_BT_INDEX";
    string constant PRODUCT_MANAGER_CA = "RESERVED_BT_PRODUCT_MANAGER"; 
    string constant FEE_MANAGER_CA = "RESERVED_BT_FEE_MANAGER"; 
    string constant MARKET_MANAGER_CA = "RESERVED_BT_MARKET_MANAGER"; 
    string constant FUND_MANAGER_CA = "RESERVED_BT_FUND_MANAGER"; 

    address immutable self; 

    IBTRegister register; 
    IBTIndex index; 
    IBTProductManager productManager; 
    IBTFeeManager feeManager; 
    IBTMarketManager marketManager; 
    IBTFundManager fundManager; 
    IBTBondManager bondManager; 

    uint256 [] investmentIds; 
    mapping(uint256=>Investment) investmentById; 
    mapping(uint256=>uint256) divestmentIdByInvestmentId; 
    mapping(uint256=>Divestment) divestmentById; 
    uint256 [] marketPositionIds; 

    constructor(address _register) {
        register        = IBTRegister(_register); 
        index           = IBTIndex(register.getAddress(INDEX_CA));  
        productManager  = IBTProductManager(register.getAddress(PRODUCT_MANAGER_CA)); 
        feeManager      = IBTFeeManager(register.getAddress(FEE_MANAGER_CA)); 
        marketManager   = IBTMarketManager(register.getAddress(MARKET_MANAGER_CA)); 
        fundManager     = IBTFundManager(register.getAddress(FUND_MANAGER_CA));
    }

    function getName() pure external returns (string memory _name){
        return name; 
    }

    function getVersion() pure external returns (uint256 _version){
        return version; 
    }

    function getInvestmentIds() view external returns (uint256 [] memory _investmentIds){
        return investmentIds; 
    }

    function getInvestment(uint256 _investmentId) view external returns (Investment memory _investment){
        return investmentById[_investmentId]; 
    } 

    function getDivestmentByInvestmentId(uint256 _investmentId) view external returns (Divestment memory _divestment){
        return divestmentById[divestmentIdByInvestmentId[_investmentId]];
    }  

    function getDivestment(uint256 _divestmentId) view external returns (Divestment memory _divestment){
        return divestmentById[_divestmentId];
    }

    function invest(ProtoInvestment memory _investment) external returns (uint256 _investmentId){
        _investmentId = index.getIndex();
        Fund memory fund_ = fundManager.getFund(_investment.fundId); 
        Market memory market_ = marketManager.getMarket(_investment.marketId); 
        Product memory product_ = productManager.getProduct(fund_.productId);
        Bond memory bond_ = bondManager.getBond(_investment.bondId); 

        require(product_.risk == market_.risk, "risk mis-match");
        require(market_.yield.min >= product_.yield.min, "insufficient market yield");
        require(product_.investmentPrincipal.min >= market_.principal.min, "insufficient fund amount");  
        require(market_.inputErc20 == fund_.erc20, "market <> fund token mis-match"); 
        require(bond_.erc20 == market_.inputErc20, "bond <> market token mis-match");
            
        IBTMarket rawMarket_ = IBTMarket(market_.marketAddress); 
        IBTFundVault fundVault_ = IBTFundVault(fund_.vault); 
        
        uint256 marketPositionId_ = index.getIndex();

        marketPositionIds.push(marketPositionId_);
        
        uint256 position_ = 0; 
        uint256 productLimitedAmount_ = 0;
        if(fund_.erc20 == NATIVE){
            productLimitedAmount_ = fundVault_.pullFunds(msg.sender);
            position_ = rawMarket_.openPosition{value : productLimitedAmount_}(fund_.owner, msg.sender, _investment.marketId, productLimitedAmount_);
        }
        else {
            productLimitedAmount_ = fundVault_.pullFunds(msg.sender);
            IERC20 erc20_ = IERC20(fund_.erc20);
            erc20_.transferFrom(fund_.vault, self, productLimitedAmount_); 
            erc20_.approve(market_.marketAddress, productLimitedAmount_);
            position_ = rawMarket_.openPosition(fund_.owner, msg.sender, _investment.marketId, productLimitedAmount_);
        } 

        uint256 maxCoverage_ = (productLimitedAmount_ * (market_.yield.max + market_.lossTolerance.max))/100; // consume max coverage
        uint256 consumptionIndex_ = bondManager.consumeCoverage(_investment.bondId, fund_.owner, maxCoverage_);

        investmentById[_investmentId] = Investment({
                                                        id : _investmentId,  
                                                        fundId : _investment.fundId,  
                                                        marketId : _investment.marketId,
                                                        positionId : position_, 
                                                        amount : productLimitedAmount_,
                                                        minimumExpectedReturn : getExpectedMiniumReturn(productLimitedAmount_,  market_),
                                                        bondId : _investment.bondId,
                                                        coverage : maxCoverage_,  
                                                        coverageConsumptionIndex : consumptionIndex_, 
                                                        treasurer : msg.sender, 
                                                        owner : fund_.owner, 
                                                        createDate : block.timestamp, 
                                                        divestmentDate : 0  
                                                    });
        return _investmentId; 
    } 

    function divest(uint256 _investmentId) external returns (uint256 _divestmentId){
        Investment memory investment_ = investmentById[_investmentId]; 
        investmentById[_investmentId].divestmentDate = block.timestamp; 
        _divestmentId = index.getIndex(); 
        
        // exit market
        Market memory market_ = marketManager.getMarket(investment_.marketId);
        IBTMarket rawMarket_ = IBTMarket(market_.marketAddress); 
        MarketSettlement memory marketSettlement_ = rawMarket_.getSettlement(rawMarket_.closePosition(investment_.positionId));
        pullInFunds(market_.marketAddress, market_.inputErc20, marketSettlement_.amount); // pull funds 

        Fund memory fund_ = fundManager.getFund(investment_.fundId);
        Product memory product_ = productManager.getProduct(fund_.productId);
        
        uint256 amountToTransmit_ = 0;
        uint256 productFee_       = 0; 
        uint256 treasurerFee_     = 0; 
        if(marketSettlement_.amount >= investment_.amount){
            uint256 yield_ = marketSettlement_.amount - investment_.amount; 
            (amountToTransmit_, productFee_, treasurerFee_) = LBTLib.resolveYieldSplit(product_, yield_, investment_.amount);  
            if(investment_.minimumExpectedReturn > amountToTransmit_){
                uint256 deficit_ = investment_.minimumExpectedReturn - amountToTransmit_; // solve with treasurer's bond 
                amountToTransmit_ += runCompensation(investment_.bondId, investment_.coverageConsumptionIndex, market_.inputErc20, deficit_);
            }
            else {
                // no action amount to transmit is above the minimum
            }
        }
        else { 
            amountToTransmit_ = marketSettlement_.amount;
            uint256 deficit_ = investment_.amount - marketSettlement_.amount; 
            if(deficit_ >= investment_.coverage){// pull all the treasurer's coverage
                amountToTransmit_ += runCompensation(investment_.bondId, investment_.coverageConsumptionIndex, market_.inputErc20, investment_.coverage);
                
                uint256 deficiency_ = deficit_ - investment_.coverage; 
                if(deficiency_ > fund_.coverage){
                    amountToTransmit_ += runCompensation(product_.bondId, fund_.consumptionIndex, market_.inputErc20, fund_.coverage); // pull all coverage for period
                }
                else {
                    amountToTransmit_ += runCompensation(product_.bondId, fund_.consumptionIndex, market_.inputErc20, deficiency_); // solve the deficiency
                }
            }
            else { 
                amountToTransmit_ += runCompensation(investment_.bondId, investment_.coverageConsumptionIndex, market_.inputErc20, deficit_); 
                uint256 guaranteedEarnings_ = investment_.minimumExpectedReturn - amountToTransmit_; 
                amountToTransmit_ += runCompensation(product_.bondId, fund_.consumptionIndex, market_.inputErc20, guaranteedEarnings_); // guarantee return
            }
        }

        
        // disburse everything 
        IBTFundVault vault_ = IBTFundVault(fundManager.getFund(investment_.fundId).vault);
        if(market_.inputErc20 == NATIVE) {
            vault_.pushFunds{value : amountToTransmit_}(amountToTransmit_, investment_.treasurer);
            payable(product_.owner).transfer(productFee_);
            payable(investment_.treasurer).transfer(treasurerFee_); 
        }
        else { 
            IERC20 erc20_  = IERC20(market_.inputErc20); 
            erc20_.approve(address(vault_), amountToTransmit_); 
            vault_.pushFunds(amountToTransmit_, investment_.treasurer);
            erc20_.transfer(product_.owner, productFee_); 
            erc20_.transfer(investment_.treasurer, treasurerFee_); 
        }
        return _divestmentId; 
    } 

    //========================================================= INTERNAL ==============================================================

    function runCompensation(uint256 _bondId, uint256 _consumptionIndex, address _erc20, uint256 _amount) internal returns (uint256 _additionalAmountToTransmit){
        bondManager.requestCompensation(_bondId, _consumptionIndex, _amount);
        pullInFunds(address(bondManager), _erc20, _amount);
        emit COMPENSATION_EVENT(_bondId, _consumptionIndex, _erc20, _amount, block.timestamp); 
        return _amount;
    }

    function pullInFunds(address _fundHolder, address _erc20, uint256 _amount) internal returns (bool _pulled) {
        if(_erc20 == NATIVE){
        }
        else {
            IERC20 erc20_  = IERC20(_erc20); 
            erc20_.transferFrom(_fundHolder, self, _amount); 
        }
        return true; 
    }

    function getExpectedMiniumReturn(uint256 _productLimitedAmount, Market memory _market) internal pure returns (uint256 _return) {
        _return = (_productLimitedAmount * _market.yield.min)/100; 
        return _return; 
    }

}


