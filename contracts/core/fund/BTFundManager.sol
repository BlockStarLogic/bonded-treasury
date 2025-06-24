// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.30;

import "../../interfaces/fund/IBTFundManager.sol"; 
import "../../interfaces/fund/IBTFundVaultFactory.sol"; 
import "../../interfaces/fund/IBTFundVault.sol";

import "../../interfaces/product/IBTProductManager.sol"; 

import "../../interfaces/fee/IBTFeeManager.sol"; 

import "../../interfaces/util/IBTVersion.sol";
import "../../interfaces/util/IBTRegister.sol"; 
import "../../interfaces/util/IBTIndex.sol"; 

import "../../lib/LBTLib.sol"; 

import {ProductStatus} from "../../structs/BTStructs.sol"; 

import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; 


contract BTFundManager is IBTVersion, IBTFundManager {

    modifier fundOwnerOnly(uint256 _fundId) {
        require(msg.sender == fundById[_fundId].owner, "fund owner only");
        _;
    }

    string constant name = "RESERVED_BT_FUND_MANAGER"; 
    uint256 constant version = 1; 

    address constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE; 

    string constant FUND_VAULT_FACTORY_CA = "RESERVED_BT_FUND_VAULT_FACTORY";
    string constant INDEX_CA = "RESERVED_BT_INDEX"; 
    string constant PRODUCT_MANAGER_CA = "RESERVED_BT_PRODUCT_MANAGER"; 
    string constant FEE_WALLET_CA = "RESERVED_BT_FEE_WALLET"; 

    address immutable self; 

    IBTRegister register; 
    IBTFundVaultFactory factory; 
    IBTIndex index; 
    IBTProductManager productManager; 
    
    uint256 [] fundIds; 
    mapping(uint256=>Fund) fundById; 
    mapping(address=>uint256[]) fundIdsByOwner; 
    mapping(uint256=>uint256[]) fundIdsByProductId;

    constructor(address _register){
        register = IBTRegister(_register); 
        index = IBTIndex(register.getAddress(INDEX_CA)); 
        factory = IBTFundVaultFactory(register.getAddress(FUND_VAULT_FACTORY_CA)); 
        self = address(this);
    }

    function getName() pure external returns (string memory _name){
        return name; 
    }

    function getVersion() pure external returns (uint256 _version){
        return version; 
    }

    function getFundIds() view external returns (uint256 [] memory _fundIds){
        return fundIds; 
    }
    function getFund(uint256 _fundId) view external returns (Fund memory _fund){
        return fundById[_fundId]; 
    }

    function getFundIdsByProductId(uint256 _productId) view external returns (uint256 [] memory _fundId){
        return fundIdsByProductId[_productId];
    }

    function createFund(string memory _name, address _owner, address _erc20, uint256 _amount, uint256 _productId) payable external returns (uint256 _fundId){
        (uint256 _productIndex, uint256 _coverage, uint256 _consumptionIndex) = productManager.procureProduct(_productId, msg.sender); 
       
        IBTFundVault vault_ = IBTFundVault(factory.getFundVault(_fundId)); 

        address feeWallet_ = register.getAddress(FEE_WALLET_CA); 
        Product memory product_ = productManager.getProduct(_productId);
        
        uint256 residual_ = _amount - product_.purchaseFee; 
        if(_erc20 == NATIVE) {
            require(msg.value >= _amount, "insufficient amount transmitted" ); 
            payable(feeWallet_).transfer(product_.purchaseFee); 
            vault_.deposit{value : residual_}(residual_);
        }
        else { 
            IERC20 erc20_ = IERC20(_erc20); 
            erc20_.transferFrom(msg.sender, self, _amount);
            erc20_.approve(address(vault_), residual_); 
            vault_.deposit(residual_);
        }
        _fundId = index.getIndex(); 
        fundIds.push(_fundId); 
        fundIdsByOwner[_owner].push(_fundId);
        fundIdsByProductId[_productId].push(_fundId); 

        fundById[_fundId] = Fund ({ 
                                id : _fundId,
                                name : _name,
                                amount : _amount,  
                                erc20 : _erc20,
                                owner : _owner, 
                                productId : _productId,
                                vault : address(vault_),
                                productIndex : _productIndex,
                                coverage :  _coverage /  product_.term.max / LBTLib.resolvePeriod(product_.payoutInterval),
                                consumptionIndex : _consumptionIndex,
                                createdDate : block.timestamp, 
                                closedDate : 0
                            });
        return _fundId; 
    }

    function closeFund(uint256 _fundId) external fundOwnerOnly(_fundId) returns (bool _closed) {
        IBTFundVault vault_ = IBTFundVault(fundById[_fundId].vault); 
        uint256 exitBalance_ = vault_.close(); 

        
        Fund memory fund_ = fundById[_fundId]; 
        productManager.releaseProduct(fund_.productId, fund_.consumptionIndex, fund_.owner); 
        
        if(fund_.erc20 == NATIVE) {
            payable(fund_.owner).transfer(exitBalance_); 
        }
        else { 
            IERC20 erc20_ = IERC20(fund_.erc20); 
            erc20_.transferFrom(fund_.vault, self, exitBalance_); 
            erc20_.transfer(fund_.owner, exitBalance_);
        }
        fundById[_fundId].closedDate = block.timestamp; 
        return true; 
    }
}