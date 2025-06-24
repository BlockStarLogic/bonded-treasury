// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.30;

import "../../interfaces/util/IBTVersion.sol"; 
import "../../interfaces/util//IBTRegister.sol"; 

import "../../interfaces/bond/IBTBondVaultFactory.sol";

import "./BTBondVault.sol"; 

contract BTBondVaultFactory is IBTVersion, IBTBondVaultFactory { 

    string constant name = "RESERVED_BT_BOND_VAULT_FACTORY"; 
    uint256 constant version = 1; 

    address [] vaults; 
    mapping(address=>bool) isKnownVaultByAddress; 

    IBTRegister register; 

    constructor(address _register) { 
        register = IBTRegister(_register); 
    }

    function getName() pure external returns (string memory _name){
        return name; 
    }

    function getVersion() pure external returns (uint256 _version){
        return version; 
    }

    function getVaults() view external returns (address [] memory _addresses){
        return vaults; 
    }

    function isKnownVault(address _address) view external returns (bool _isKnown){
        return isKnownVaultByAddress[_address]; 
    }

    function getBondVault(uint256 _bondId, address _bondToken) external returns (address _vault){
        _vault = address(new BTBondVault(address(register), _bondId, _bondToken)); 
        vaults.push(_vault); 
        isKnownVaultByAddress[_vault] = true; 
        return _vault; 
    }

}