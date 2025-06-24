// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.30;

import "../../interfaces/bond/IBTBondManager.sol"; 

import "../../interfaces/product/IBTProductManager.sol"; 

import "../../interfaces/fee/IBTFeeManager.sol"; 

import "../../interfaces/util/IBTVersion.sol";
import "../../interfaces/util/IBTRegister.sol"; 
import "../../interfaces/util/IBTIndex.sol"; 

import "../../lib/LBTLib.sol"; 

import {ProductStatus} from "../../structs/BTStructs.sol"; 

import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; 

contract BTProductManager is IBTVersion, IBTProductManager { 

    modifier productOwnerOnly(uint256 _productId) {
        require(msg.sender == productById[_productId].owner || msg.sender == register.getAddress(ADMIN_CA), "product owner only");
        _; 
    }

    modifier adminOnly () { 
        require(msg.sender == register.getAddress(ADMIN_CA), "admin only"); 
        _;
    }

    modifier knownAddressOnly() {
        require(register.isKnownAddress(msg.sender), "known address only");
        _; 
    }

    string constant name = "RESERVED_BT_BOND_MANAGER"; 
    uint256 constant version = 1; 

    address constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE; 
    
    string constant ADMIN_CA = "RESERVED_BT_ADMIN"; 
    string constant INDEX_CA = "RESERVED_BT_INDEX"; 
    string constant REGISTER_CA = "RESERVED_BT_REGISTER"; 
    string constant FEE_MANAGER_CA = "RESERVED_BT_FEE_MANAGER"; 
    string constant FEE_WALLET_CA = "RESERVED_FEE_WALLET";
    string constant BOND_MANAGER_CA = "RESERVED_BOND_MANAGER"; 

    string constant CREATE_PRODUCT_FEE = "CREATE_PRODUCT_FEE"; 

    address immutable self; 

    IBTRegister register; 
    IBTIndex index; 
    IBTFeeManager feeManager; 
    IBTBondManager bondManager; 

    uint256 [] productIds; 
    mapping(uint256=>Product) productById; 
    mapping(uint256=>bool) knownByProductId; 
    mapping(address=>mapping(uint256=>bool)) inUseByBondIdByOwner; 

    mapping(uint256=>mapping(uint256=>address)) purchaserByProductIndexByProductId; 
    mapping(uint256=>mapping(address=>bool)) hasPurchaseByPurchaserByProductId;
    mapping(uint256=>uint256[]) productIndicesByProductId; 
    mapping(uint256=>mapping(uint256=>address)) purchaserByConsumptionIndexByProductId;

    constructor(address _register) { 
        register = IBTRegister(_register); 
        index = IBTIndex(register.getAddress(INDEX_CA)); 
        feeManager = IBTFeeManager(register.getAddress(FEE_MANAGER_CA)); 
        bondManager = IBTBondManager(register.getAddress(BOND_MANAGER_CA)); 
    }

    function getName() pure external returns (string memory _name){
        return name; 
    }

    function getVersion() pure external returns (uint256 _version){
        return version; 
    }

    function getProductIds() view external returns (uint256 [] memory _productIds){
        return productIds; 
    }

    function getProduct(uint256 _productId) view external returns (Product memory _product){
        return productById[_productId];
    }

    function isKnownProductId(uint256 _productId) view external returns (bool _isKnown){
        return knownByProductId[_productId]; 
    }

    function createProduct(ProtoProduct memory _pProduct) payable external returns (uint256 _productId){
        Fee memory createProductFee = feeManager.getFee(CREATE_PRODUCT_FEE); 
        if(createProductFee.erc20 == NATIVE) {
            require(msg.value >= createProductFee.amount, "insufficient native fee transmitted"); 
            payable(register.getAddress(FEE_WALLET_CA)).transfer(createProductFee.amount);
        }
        else { 
            IERC20 erc20_ = IERC20(createProductFee.erc20); 
            erc20_.transferFrom(msg.sender, self, createProductFee.amount); 
            erc20_.transfer(register.getAddress(FEE_WALLET_CA), createProductFee.amount); 
        }
        Bond memory bond_ = bondManager.getBond(_pProduct.bondId); 
        require(bond_.owner == msg.sender, "bond ownership mis-match"); 
        require(bond_.bondType == BondType.PRODUCT, "bond type mis-match"); 
        require(!inUseByBondIdByOwner[bond_.owner][bond_.id], "bond already in use"); 
        inUseByBondIdByOwner[bond_.owner][bond_.id] = true; 

        require(LBTLib.hasValidCoverage(bond_, _pProduct), "insufficient coverage available"); 
        _productId = index.getIndex();
        productIds.push(_productId); 
        knownByProductId[_productId] = true; 
        productById[_productId] = Product({
                                            id : _productId,  
                                            name : _pProduct.name,
                                            owner : msg.sender, 
                                            bondId : _pProduct.bondId,
                                            erc20 : bond_.erc20,
                                            risk : _pProduct.risk, 
                                            bansAllowed : _pProduct.bansAllowed, 
                                            investmentPrincipal : _pProduct.investmentPrincipal,
                                            yield : _pProduct.yield,
                                            payoutInterval : _pProduct.payoutInterval,
                                            term : _pProduct.term, 
                                            inventory : _pProduct.inventory, 
                                            expiryDate : block.timestamp + _pProduct.term.max,
                                            status : ProductStatus.AVAILABLE,
                                            treasurerFee : _pProduct.treasurerFee, 
                                            purchaseFee : _pProduct.purchaseFee
                                          });
        return _productId; 
    }

    function procureProduct(uint256 _productId, address _purchaser) external returns (uint256 _productIndex, uint256 _coverage, uint256 _consumptionIndex) {
        require(productById[_productId].status == ProductStatus.AVAILABLE, "product not available");
        require(!hasPurchaseByPurchaserByProductId[_productId][_purchaser], "product already purchased"); 
        hasPurchaseByPurchaserByProductId[_productId][_purchaser] = true; 
        productById[_productId].inventory--; // decrease the inventory
        if(productById[_productId].inventory == 0){
            productById[_productId].status = ProductStatus.SOLDOUT; 
        }
      
        _coverage = LBTLib.getCoverage(productById[_productId]);
        _consumptionIndex = bondManager.consumeCoverage(productById[_productId].bondId, _purchaser, _coverage);
        purchaserByConsumptionIndexByProductId[_productId][_consumptionIndex] = _purchaser; 

        _productIndex = productIndicesByProductId[_productId].length; 
        productIndicesByProductId[_productId].push(_productIndex); 
        purchaserByProductIndexByProductId[_productId][_productIndex] = _purchaser; 
        return (_productIndex, _coverage, _consumptionIndex); 
    }
    
    function releaseProduct(uint256 _productId, uint256 _consumptionIndex, address _purchaser) external knownAddressOnly returns (bool _released){
        require(purchaserByConsumptionIndexByProductId[_productId][_consumptionIndex] == _purchaser, "purchaser mis-match");
        return bondManager.releaseCoverage(productById[_productId].bondId, _consumptionIndex);
    }

    function expireProduct(uint256 _productId) external productOwnerOnly(_productId) returns (bool _expired){
        productById[_productId].expiryDate = block.timestamp; 
        productById[_productId].status = ProductStatus.EXPIRED; 
        return true; 
    }

    function cancelProduct(uint256 _productId) external productOwnerOnly(_productId)returns (bool _cancelled){
         productById[_productId].status = ProductStatus.CANCELLED; 
        return true; 
    }

    function freezeProduct(uint256 _productId) external adminOnly returns (bool _frozen) {
        require(productById[_productId].status == ProductStatus.AVAILABLE, "invalid status"); 
        productById[_productId].status = ProductStatus.FROZEN; 
        return true; 
    }

    function unfreezeProduct(uint256 _productId) external adminOnly returns (bool _frozen) {
        require(productById[_productId].status == ProductStatus.FROZEN, "invalid status"); 
        productById[_productId].status = ProductStatus.AVAILABLE; 
        return true; 
    }

    //===================================== INTERNAL =============================================================================




}