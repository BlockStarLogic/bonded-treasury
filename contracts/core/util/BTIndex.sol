// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.30;

import "../../interfaces/util/IBTIndex.sol";
import "../../interfaces/util/IBTRegister.sol"; 
import "../../interfaces/util/IBTVersion.sol";

contract BTIndex is IBTIndex, IBTVersion { 

    modifier knownAddressesOnly () { 
        require(register.isKnownAddress(msg.sender), "unknown address");
        _; 
    }

    string constant name = "RESERVED_BT_INDEX"; 
    uint256 constant version = 1;

    IBTRegister register; 
   
    mapping(address=>mapping(uint256=>bool)) isKnownIndexByIndexByAddress; 
    mapping(address=>uint256[]) indiciesByAddress; 
    mapping(address=>uint256) indexByAddress; 
    mapping(address=>bool) knownAddress; 

    constructor(address _register) {
        register = IBTRegister(_register); 
    }

    function getName() pure external returns (string memory _name){
        return name; 
    }

    function getVersion() pure external returns (uint256 _version){
        return version; 
    }

    function isKnownIndex(uint256 _index) view external returns (bool _isKnown){
        return isKnownIndexByIndexByAddress[msg.sender][_index];  
    }

    function getIndex() external knownAddressesOnly returns (uint256 _index){
        if(!knownAddress[msg.sender]){
            _index = 0; 
            knownAddress[msg.sender] = true; 
            indexByAddress[msg.sender] = _index; 
        }
        else { 
            _index = indexByAddress[msg.sender]++; 
        }
        isKnownIndexByIndexByAddress[msg.sender][_index] = true; 
        indiciesByAddress[msg.sender].push(_index); 
        return _index; 
    }
}