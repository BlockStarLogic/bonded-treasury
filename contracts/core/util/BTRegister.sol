// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.30;

import "../../interfaces/util/IBTIndex.sol";
import "../../interfaces/util/IBTRegister.sol"; 
import "../../interfaces/util/IBTVersion.sol";

contract BTRegister is IBTVersion, IBTRegister { 

    modifier adminOnly () { 
        require(msg.sender == addressByName[ADMIN_CA], "admin only");
        _; 
    }

    string constant name = "RESERVED_BT_REGISTER"; 
    uint256 constant version = 1; 

    string constant ADMIN_CA = "RESERVED_BT_ADMIN";

    address self; 

    string [] names; 
    mapping(string=>bool) isKnownNameByName; 
    mapping(address=>bool) isKnownAddressByAddress; 
    mapping(string=>address) addressByName; 
    mapping(address=>string) nameByAddress;
    mapping(string=>uint256) versionByName; 

    constructor(address _admin) {
        addAddressInternal(ADMIN_CA, _admin, 0);
        self = address(this); 
        addAddressInternal(name, self, version);
    }
    
    function getName() pure external returns (string memory _name){
        return name; 
    }

    function getVersion() pure external returns (uint256 _version){
        return version; 
    }

    function isKnownAddress(address _address) view external returns (bool _isKnown){
        return isKnownAddressByAddress[_address]; 
    }

    function getAddress(string memory _name) view external returns (address _address){
        return addressByName[_name]; 
    }

    function getName(address _address) view external returns (string memory _name){
        return nameByAddress[_address]; 
    }

    function getVersion(string memory _name) view external returns (uint256 _version) {
        return versionByName[_name]; 
    }

    function addVersionAddress(address _address) external adminOnly returns (bool _added){
        IBTVersion versioned = IBTVersion(_address); 
        addAddressInternal(versioned.getName(), _address, versioned.getVersion()); 
        return true; 
    }

    function addAddress(string memory _name, address _address, uint256 _version) external adminOnly returns (bool _added) { 
        return addAddressInternal(_name, _address, _version); 
    }

    //============================== INTERNAL ==========================================

    function addAddressInternal(string memory _name, address _address, uint256 _version) internal returns (bool _added){
        if(!isKnownNameByName[_name]) {
            names.push(_name);
            isKnownNameByName[_name] = true; 
        }  
        isKnownAddressByAddress[_address] = true;  
        addressByName[_name] = _address; 
        nameByAddress[_address] = _name;
        versionByName[_name] = _version; 
        return true; 
    }
}