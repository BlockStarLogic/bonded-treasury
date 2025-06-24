// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.30;

import "../../interfaces/fee/IBTFeeManager.sol"; 
import "../../interfaces/util/IBTVersion.sol"; 
import "../../interfaces/util/IBTRegister.sol"; 

contract BTFeeManager is IBTVersion, IBTFeeManager {
    modifier adminOnly () { 
        require(msg.sender == register.getAddress(ADMIN_CA), "admin only");
        _; 
    }

    string constant name = "RESERVED_BT_FEE_MANAGER"; 
    uint256 constant version = 1;

    string constant ADMIN_CA = "RESERRVED_BT_ADMIN"; 

    IBTRegister register;  

    string [] names; 
    mapping(string=>bool) knownNameByName;
    mapping(string=>Fee) feeByName; 

    constructor(address _register) { 
        register = IBTRegister(_register); 

    }

    function getName() pure external returns (string memory _name){
        return name; 
    }

    function getVersion() pure external returns (uint256 _version){
        return version; 
    }

    function getNames() view external returns (string [] memory _names){
        return names; 
    }

    function getFee(string memory _name) view external returns (Fee memory _fee){
        return feeByName[_name]; 
    }

    function addFee(string memory _name, address _erc20, uint256 _amount, bool _isPercentage) external adminOnly returns (bool _added) {
        if(!knownNameByName[_name]){
            names.push(_name); 
            knownNameByName[_name] = true; 
        }
        feeByName[_name] = Fee({
                                name : _name, 
                                erc20 : _erc20, 
                                amount : _amount, 
                                isPercentage : _isPercentage
                                });
        return true; 
    }   
}