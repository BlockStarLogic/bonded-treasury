// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.30;

import "../../interfaces/market/IBTMarketManager.sol";
import "../../interfaces/market/IBTMarketVehicle.sol"; 
import "../../interfaces/market/IBTMarketVaultFactory.sol"; 

import "../../interfaces/fee/IBTFeeManager.sol";

import "../../interfaces/util/IBTVersion.sol";
import "../../interfaces/util/IBTRegister.sol"; 
import "../../interfaces/util/IBTIndex.sol"; 

import {MarketStatus} from "../../structs/BTStructs.sol"; 


contract BTMarketManager is IBTVersion, IBTMarketManager { 

    modifier marketOwnerOnly (uint256 _marketId) {
        require(msg.sender == marketById[_marketId].owner || msg.sender == register.getAddress(ADMIN_CA), "market owner or admin only"); 
        _; 
    }

    string constant name = "RESERVED_BT_MARKET_MANAGER"; 
    uint256 constant version = 1; 

    address constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE; 

    string constant INDEX_CA = "RESERVED_BT_INDEX"; 
    string constant MARKET_VAULT_FACTORY_CA = "RESERVED_BT_MARKET_VAULT_FACTORY"; 
    string constant ADMIN_CA = "RESERVED_BT_ADMIN"; 

    string constant FEE_MANAGER_CA = "RESERVED_FEE_MANAGER";
    string constant FEE_WALLET_CA = "RESERVED_FEE_WALLET"; 

    address immutable self; 

    IBTRegister register; 
    IBTIndex index;  
    IBTFeeManager feeManager;  

    uint256 [] marketIds; 
    mapping(uint256=>bool) knownMarketId; 
    mapping(uint256=>Market) marketById; 

    constructor(address _register) {
        register = IBTRegister(_register); 
        index = IBTIndex(register.getAddress(INDEX_CA)); 
        feeManager = IBTFeeManager (register.getAddress(FEE_MANAGER_CA));
    }

    function getName() pure external returns (string memory _name){
        return name; 
    }

    function getVersion() pure external returns (uint256 _version){
        return version; 
    }

    function getMarketIds() view external returns (uint256 [] memory _marketIds){
        return marketIds; 
    }

    function getMarket(uint256 _marketId) view external returns (Market memory _market){
        return marketById[_marketId];
    }

    function creatMarket(ProtoMarket memory _pMarket ) payable external returns (uint256 _marketId){
        _marketId = index.getIndex(); 
        knownMarketId[_marketId] = true;
       marketById[_marketId] = Market ({ 
                                        id : _marketId, 
                                        name : _pMarket.name, 
                                        owner : _pMarket.owner, 
                                        mType : _pMarket.mType, 
                                        bondId : _pMarket.bondId, 
                                        risk : _pMarket.risk, 
                                        yield : _pMarket.yield,
                                        lossTolerance : _pMarket.lossTolerance, 
                                        principal : _pMarket.principal, 
                                        inputErc20 : _pMarket.inputErc20, 
                                        outputErc20 : _pMarket.outputErc20,
                                        vault : IBTMarketVaultFactory(register.getAddress(MARKET_VAULT_FACTORY_CA)).getMarketVault(_marketId), 
                                        vehicle : _pMarket.vehicle, 
                                        vType : _pMarket.vType, 
                                        term : _pMarket.term, 
                                        slots : _pMarket.slots,  
                                        status : MarketStatus.OPEN,
                                        created : block.timestamp, 
                                        expired : block.timestamp + _pMarket.term.max
                                    });
        
        return _marketId; 
    }

    function closeMarket(uint256 _marketId) external marketOwnerOnly(_marketId) returns (bool _marketClosed){
        require(knownMarketId[_marketId] && marketById[_marketId].status != MarketStatus.CLOSED, "Market already closed"); 
        marketById[_marketId].status = MarketStatus.CLOSED; 
        IBTMarketVehicle vehicle_ = IBTMarketVehicle(marketById[_marketId].vehicle); 
        (uint256 _marketBalance, uint256 _compensationIssued) = vehicle_.flushMarket(_marketId);

        return true; 
    }
}