// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.30;

import "../../interfaces/fund/IBTFundVaultFactory.sol"; 

import "../../interfaces/util/IBTVersion.sol";
import "../../interfaces/util/IBTRegister.sol"; 

import "./BTFundVault.sol";

contract BTFundVaultFactory is IBTFundVaultFactory, IBTVersion { 
    
    modifier fundManagerOnly { 
        require(msg.sender == register.getAddress(FUND_MANAGER_CA), "fund manager only"); 
        _; 
    }
    
    modifier adminOnly () { 
        require(msg.sender == register.getAddress(ADMIN_CA), "admin only"); 
        _;
    }

    string constant name = "RESERVED_BT_FUND_VAULT_FACTORY"; 
    uint256 constant version = 1; 

    string constant ADMIN_CA = "RESERVED_BT_ADMIN"; 
    string constant FUND_MANAGER_CA = "RESERVED_BT_FUND_MANAGER"; 

    IBTRegister register; 

    address [] fundVaults;
    mapping(uint256=>address) fundVaultById;  
    mapping(address=>bool) isKnownByFundVaultAddress;

    constructor(address _register) {
        register = IBTRegister(_register); 
    }

    function getName() pure external returns (string memory _name){
        return name; 
    }

    function getVersion() pure external returns (uint256 _version){
        return version; 
    }

    function isKnownVault(address _fundVault) view external returns (bool _isKnown){
        return isKnownByFundVaultAddress[_fundVault]; 
    }

    function getFundVaults() view adminOnly external returns (address [] memory _fundVaults){
        return fundVaults; 
    }

    function getFundVault(uint256 _fundId) external fundManagerOnly returns (address _fundVault){
        _fundVault = address(new BTFundVault(address(register), _fundId)); 
        fundVaults.push(_fundVault);
        fundVaultById[_fundId] = _fundVault;
        isKnownByFundVaultAddress[_fundVault] = true; 
        return _fundVault; 
    }
}