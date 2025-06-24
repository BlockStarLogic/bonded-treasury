// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.30;

import "../../interfaces/bond/IBTBondManager.sol"; 
import "../../interfaces/bond/IBTBondVault.sol"; 
import "../../interfaces/bond/IBTBondVaultFactory.sol"; 

import "../../interfaces/fee/IBTFeeManager.sol"; 

import "../../interfaces/util/IBTVersion.sol";
import "../../interfaces/util/IBTRegister.sol"; 
import "../../interfaces/util/IBTIndex.sol"; 

import "../../lib/LBTLib.sol"; 

import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; 

import {BondStatus, CoverageStatus, BondSettlementStatus, BOND_EVENT,  COVERAGE_EVENT, TOP_UP_EVENT} from "../../structs/BTStructs.sol"; 


contract BTBondManager is IBTVersion, IBTBondManager { 

    using LBTLib for address[]; 

    modifier adminOnly () { 
        require(msg.sender == register.getAddress(ADMIN_CA), "admin only"); 
        _;
    }

    modifier bondOwnerOnly(uint256 _bondId) { 
        require(msg.sender == bondById[_bondId].owner || msg.sender == register.getAddress(ADMIN_CA), "bond owner or admin only"); 
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
    string constant FACTORY_CA = "RESERVED_BT_BOND_VAULT_FACTORY"; 
    string constant REGISTER_CA = "RESERVED_BT_REGISTER"; 
    string constant FEE_MANAGER_CA = "RESERVED_BT_FEE_MANAGER"; 
    string constant FEE_WALLET_CA = "RESERVED_FEE_WALLET";
    
    string constant CREATE_BOND_FEE = "CREATE_BOND_FEE";

    address immutable self; 

    IBTRegister register; 
    IBTIndex index; 
    IBTBondVaultFactory factory; 
    IBTFeeManager feeManager; 

    uint256 [] bondIds; 
    mapping(uint256=>Bond) bondById; 
    mapping(string=>mapping(address=>uint256)) bondIdByOwnerByName;  
    mapping(address=>mapping(string=>bool) ) knownByNameByOwner;  
    mapping(string=>uint256) bondIdByName; 

    mapping(uint256=>address[]) coverageConsumersByBondId;
    mapping(uint256=>mapping(address=>uint256)) coverageByConsumerByBondId;
    mapping(uint256=>mapping(address=>bool)) knownConsumerByConsumerByBondId;
    mapping(uint256=>mapping(uint256=>bool)) knownByConsumptionIndexByBondId;  
    mapping(uint256=>mapping(uint256=>address)) consumerByConsumptionIndexByBondId; 

    uint256 [] settlementIds; 
    mapping(uint256=>BondSettlement) settlementById; 

    mapping(address=>uint256[]) bondIdsByOwner; 

    constructor(address _register) { 
        register = IBTRegister(_register); 
        index = IBTIndex(register.getAddress(INDEX_CA)); 
        factory = IBTBondVaultFactory(register.getAddress(FACTORY_CA)); 
        feeManager = IBTFeeManager(register.getAddress(FEE_MANAGER_CA)); 
    }

    function getName() pure external returns (string memory _name){
        return name; 
    }

    function getVersion() pure external returns (uint256 _version){
        return version; 
    }

    function getOwnedBondIds() view external returns (uint256 [] memory _bondIds) {
        return bondIdsByOwner[msg.sender]; 
    }

    function getBondIds() view external returns (uint256 [] memory _bondIds){
        return bondIds; 
    }

    function getBond(uint256 _bondId) view external returns (Bond memory _bond){
        return bondById[_bondId]; 
    }

    function getBond(string memory _bondName, address _owner) view external returns (Bond memory _bond){
        return bondById[bondIdByOwnerByName[_bondName][_owner]]; 
    }

    function getOutstandingCoverageConsumers(uint256 _bondId) view external returns (uint256 _outstandingCoverageConsumerCount){
        return coverageConsumersByBondId[_bondId].length;
    }

    function getSettlementIds() view external returns (uint256 [] memory _ids){
        return settlementIds; 
    }

    function getSettlement(uint256 _settlementId) view external returns (BondSettlement memory _settlement){
        return settlementById[_settlementId]; 
    }

    function createBond(address _owner,  string memory _name, address _erc20, uint256 _amount, Range memory _consumptionPerUser, BondType _type) payable external returns (uint256 _bondId){
        
        require(!knownByNameByOwner[msg.sender][_name],"name already used");
        knownByNameByOwner[msg.sender][_name] = true;
        
        _bondId = index.getIndex();
        bondIds.push(_bondId); 
        bondIdByName[_name] = _bondId; 
        bondIdsByOwner[msg.sender].push(_bondId);
        IBTBondVault vault_ = IBTBondVault(factory.getBondVault(_bondId, _erc20)); 

        address feeWallet = register.getAddress(FEE_WALLET_CA); 
        uint256 fee_ = calculateFee(_amount); 
        uint256 residual_ = _amount - fee_; 
        bool native_ = (_erc20 == NATIVE);

        if(native_) {
            require(msg.value >= _amount, "insufficient value transmitted");

            payable(feeWallet).transfer(fee_);  // collect fee 

            vault_.store{value : residual_}(residual_); // store balance 
        }
        else { 
            IERC20 erc20_ = IERC20(_erc20);
            erc20_.transferFrom(msg.sender, self, _amount); 

            erc20_.transfer(feeWallet, fee_); // collect fee

            erc20_.approve(address(vault_), residual_);  // store balance
            vault_.store(residual_); 
        }

        bondById[_bondId] = Bond({
                                    id : _bondId, 
                                    name : _name,  
                                    amount : residual_,  
                                    erc20 : _erc20, 
                                    createDate : block.timestamp, 
                                    owner : _owner,  
                                    consumptionPerUser : _consumptionPerUser,  
                                    residual : residual_, 
                                    coverage : residual_, 
                                    lostCoverage : 0,
                                    status : BondStatus.ACTIVE,
                                    vault : address(vault_),
                                    bondType : _type
                                });
        emit BOND_EVENT (_bondId, residual_, bondById[_bondId].owner, bondById[_bondId].status); 
        
        return _bondId; 
    }

    function consumeCoverage(uint256 _bondId, address _consumer, uint256 _amount) external knownAddressOnly returns (uint256 _consumptionIndex){
        require(bondById[_bondId].coverage >= _amount, "insufficient coverage"); 
        require(bondById[_bondId].status == BondStatus.ACTIVE, "invalid bond status"); 

        require(!knownConsumerByConsumerByBondId[_bondId][_consumer], "coverage already consumed once"); 
        knownConsumerByConsumerByBondId[_bondId][_consumer] = true; 
       
        bondById[_bondId].coverage -= _amount; 
        coverageByConsumerByBondId[_bondId][_consumer] = _amount; 
        
        coverageConsumersByBondId[_bondId].push(_consumer);
        _consumptionIndex = coverageConsumersByBondId[_bondId].length;
       
        require(!knownByConsumptionIndexByBondId[_bondId][_consumptionIndex],"consumption index in use"); 
        knownByConsumptionIndexByBondId[_bondId][_consumptionIndex] = true; 
        
        consumerByConsumptionIndexByBondId[_bondId][_consumptionIndex] = _consumer;
        
        emit COVERAGE_EVENT(_bondId, _consumptionIndex, _amount, _consumer, CoverageStatus.CONSUMED );

        return _consumptionIndex;  
    }

    function releaseCoverage(uint256 _bondId, uint256 _consumptionIndex) external knownAddressOnly returns (bool _released){
        require(knownByConsumptionIndexByBondId[_bondId][_consumptionIndex], "unknown consumption index"); 
        
        address consumer_ = consumerByConsumptionIndexByBondId[_bondId][_consumptionIndex]; 
        delete consumerByConsumptionIndexByBondId[_bondId][_consumptionIndex]; 
        
        uint256 coverage_ = coverageByConsumerByBondId[_bondId][consumer_]; 
        delete coverageByConsumerByBondId[_bondId][consumer_];

        bondById[_bondId].coverage += coverage_; 
        coverageConsumersByBondId[_bondId] = coverageConsumersByBondId[_bondId].remove(consumer_); 
       
        delete knownConsumerByConsumerByBondId[_bondId][consumer_]; 

        delete knownByConsumptionIndexByBondId[_bondId][_consumptionIndex]; 

        emit COVERAGE_EVENT(_bondId, _consumptionIndex, coverage_, consumer_, CoverageStatus.RELEASED );

        return true; 
    }

    function requestCompensation(uint256 _bondId, uint256 _consumptionIndex, uint256 _amount) external knownAddressOnly returns (uint256 _settlementId){
        
        address consumer_ = consumerByConsumptionIndexByBondId[_bondId][_consumptionIndex]; 
        uint256 coverage_ = coverageByConsumerByBondId[_bondId][consumer_]; 
        uint256 amountToCompensate_ = 0;
        BondSettlementStatus status_;  
        uint256 coverageBalance_ = 0; 
        if(coverage_ >= _amount) {
            amountToCompensate_ = _amount;
            coverageBalance_ = coverage_ - _amount; 
            status_ = BondSettlementStatus.COMPLETE;
        }
        else {
            amountToCompensate_ = coverage_; 
            status_ = BondSettlementStatus.DEFICIENT;
        }

        bondById[_bondId].residual -= amountToCompensate_; 
        bondById[_bondId].lostCoverage += amountToCompensate_; 
        bondById[_bondId].coverage += coverageBalance_; 

        IBTBondVault vault_ = IBTBondVault(bondById[_bondId].vault); 
        vault_.retrieve(amountToCompensate_);
        if(bondById[_bondId].erc20 == NATIVE){
            payable(msg.sender).transfer(amountToCompensate_);
        }
        else {
            IERC20(bondById[_bondId].erc20).approve(msg.sender, amountToCompensate_);
        }
        _settlementId = index.getIndex(); 
        settlementById[_settlementId] = BondSettlement({
                                                    id : _settlementId,  
                                                    bondId : _bondId,  
                                                    amount : amountToCompensate_,  
                                                    consumer : consumer_,
                                                    executor : msg.sender, 
                                                    settlementDate : block.timestamp, 
                                                    status : status_
                                                });

        delete consumerByConsumptionIndexByBondId[_bondId][_consumptionIndex]; 
        delete coverageByConsumerByBondId[_bondId][consumer_];
        coverageConsumersByBondId[_bondId] = coverageConsumersByBondId[_bondId].remove(consumer_); 
        delete knownConsumerByConsumerByBondId[_bondId][consumer_]; 
        delete knownByConsumptionIndexByBondId[_bondId][_consumptionIndex]; 

        emit COVERAGE_EVENT(_bondId, _consumptionIndex, amountToCompensate_, consumer_, CoverageStatus.SPENT);

        return _settlementId; 
    }

    function topupBond(uint256 _bondId, uint256 _amount) external payable returns (uint256 _topUpId) {
        _topUpId = index.getIndex(); 
        uint256 deficit_ = bondById[_bondId].amount - bondById[_bondId].residual;
        uint256 change_ = 0;  
        uint256 amountToStore_ = 0;
        if(deficit_ <= _amount){ 
            amountToStore_ = deficit_; 
            bondById[_bondId].status = BondStatus.ACTIVE; 
            change_ = _amount - amountToStore_;  
        }
        else {    
            amountToStore_ = _amount;  
        }
        bondById[_bondId].residual += amountToStore_;
        if(bondById[_bondId].erc20 == NATIVE){
            require(msg.value >= _amount, "insufficient amount transmitted"); 
            IBTBondVault(bondById[_bondId].vault).store{value : amountToStore_}(amountToStore_); 
            if(change_ >0){
                payable(msg.sender).transfer(change_); 
            }
        }
        else { 
            IERC20 erc20_ = IERC20(bondById[_bondId].erc20); 
            erc20_.transferFrom(msg.sender, self, amountToStore_); 
            erc20_.approve(bondById[_bondId].vault, amountToStore_); 
            IBTBondVault(bondById[_bondId].vault).store(amountToStore_); 
        }
        emit TOP_UP_EVENT(_bondId, bondById[_bondId].amount, bondById[_bondId].residual, _amount, msg.sender, bondById[_bondId].status);
    }

    function releaseBond(uint256 _bondId) external bondOwnerOnly(_bondId) returns (bool _closed){
        require(coverageConsumersByBondId[_bondId].length == 0, "consumers still outstanding ");
        bondById[_bondId].status = BondStatus.SETTLED; 
        IBTBondVault vault_ = IBTBondVault(bondById[_bondId].vault); 
        uint256 balance_ =  vault_.close(); 
        if(bondById[_bondId].erc20 == NATIVE){
            payable(bondById[_bondId].owner).transfer(balance_);
        }
        else { 
            IERC20 erc20_ = IERC20(bondById[_bondId].erc20); 
            erc20_.transferFrom(bondById[_bondId].vault, self, balance_); 
            erc20_.transfer(bondById[_bondId].owner, balance_); 
        }
        emit BOND_EVENT (_bondId, balance_, bondById[_bondId].owner, bondById[_bondId].status); 
        return true; 
    }

    //========================================== INTERNAL ============================================================

    function calculateFee(uint256 _amount) internal view returns (uint256 _fee) {
        Fee memory fee_ = feeManager.getFee(CREATE_BOND_FEE);
        _fee = (_amount * (fee_.amount))/100; 
        return _fee; 
    }
}