// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.30;

import "../../interfaces/market/IBTMarketManager.sol";
import "../../interfaces/market/IBTMarketVaultFactory.sol"; 


import "../../interfaces/util/IBTVersion.sol";
import "../../interfaces/util/IBTRegister.sol"; 
import "../../interfaces/util/IBTIndex.sol"; 

import "./BTMarketVault.sol"; 

contract BTMarketVaultFactory is IBTMarketVaultFactory, IBTVersion { 

    modifier adminOnly () { 
        require(msg.sender == register.getAddress(ADMIN_CA), "admin only"); 
        _;
    }

    modifier marketManagerOnly () { 
        require(msg.sender == register.getAddress(MARKET_MANAGER_CA), "market manager only"); 
        _;
    }

    string constant name = "BT_MARKET_VAULT"; 
    uint256 constant version = 1; 

    string constant ADMIN_CA = "RESERVED_BT_ADMIN"; 
    string constant MARKET_MANAGER_CA = "RESERVED_BT_MARKET_MANAGER"; 

    IBTRegister register; 

    address [] vaults; 
    mapping(address=>bool) isKnownByVaultAddress; 
    mapping(uint256=>bool) hasVaultByMarketId; 
    mapping(uint256=>address) vaultAddressByMarket; 

    constructor(address _register) { 
        register = IBTRegister(_register);
    }

    function getName() pure external returns (string memory _name){
        return name; 
    }

    function getVersion() pure external returns (uint256 _version){
        return version; 
    }

    function getMarketVaults() view external adminOnly returns (address[] memory _vaults){
        return vaults; 
    } 

    function isKnownVault(address _address) view external returns (bool _isKnown){ 
        return isKnownByVaultAddress[_address]; 
    }

    function getMarketVault(uint256 _marketId) external marketManagerOnly returns (address _marketVault){ 
        if(hasVaultByMarketId[_marketId]){
            return vaultAddressByMarket[_marketId];
        }
        hasVaultByMarketId[_marketId] = true; 
        _marketVault = address( new BTMarketVault(address(register), _marketId)); 
        vaultAddressByMarket[_marketId] = _marketVault;
        vaults.push(_marketVault); 
        isKnownByVaultAddress[_marketVault] = true; 
        return _marketVault; 
    }
}