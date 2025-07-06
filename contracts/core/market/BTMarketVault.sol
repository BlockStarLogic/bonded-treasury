// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.30;

import "../../interfaces/market/IBTMarketManager.sol";
import "../../interfaces/market/IBTMarketVault.sol"; 


import "../../interfaces/util/IBTVersion.sol";
import "../../interfaces/util/IBTRegister.sol"; 

import {Market} from "../../structs/BTStructs.sol"; 

import "@openzeppelin/contracts/interfaces/IERC20.sol"; 

contract BTMarketVault is IBTMarketVault, IBTVersion { 

    modifier marketVehicleOnly () { 
        require(msg.sender == market.vehicle, "market vehicle only"); 
        _; 
    }

    string constant name = "BT_MARKET_VAULT"; 
    uint256 constant version = 1; 

    address constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE; 

    string constant MARKET_MANAGER_CA = "RESERVED_MARKET_MANAGER"; 

    address immutable self; 
    Market market; 


    IBTRegister register;

    uint256 [] positionIds;
    mapping(uint256=>bool) knownPositionId;  
    mapping(uint256 => uint256) balanceByPositionId;
 
    constructor(address _register, uint256 _marketId) { 
        register = IBTRegister(_register); 
        market = IBTMarketManager(register.getAddress(MARKET_MANAGER_CA)).getMarket(_marketId);  
    }

    function getName() pure external returns (string memory _name){
        return name; 
    }

    function getVersion() pure external returns (uint256 _version){
        return version; 
    }

    function getMarketId() view external returns (uint256 _marketId){
        return market.id; 
    }

    function getPositionIds() view external returns (uint256 [] memory _positionIds){ 
        return positionIds; 
    }

    function getBalance(uint256 _positionId) view external returns (uint256 _balance){
        return balanceByPositionId[_positionId]; 
    }

    function depositBalance(uint256 _position, uint256 _balance) payable marketVehicleOnly external returns (uint256 _totolBalance){
        require(!knownPositionId[_position], "position already held for this market"); 
        balanceByPositionId[_position] = _balance;

        if(market.outputErc20 == NATIVE) {
            require(msg.value == _balance, "balance transmission mis-match"); 
            return self.balance; 
        } 
        else { 
            IERC20 erc20_ = IERC20(market.outputErc20); 
            erc20_.transferFrom(msg.sender, self, _balance); 
            return erc20_.balanceOf(self); 
        }

    }

    function withdrawBalance(uint256 _position) external marketVehicleOnly returns (uint256 _balance){
        require(knownPositionId[_position], "unknown position"); 
        knownPositionId[_position] = false; 
        _balance = balanceByPositionId[_position];
        if(market.outputErc20 == NATIVE) {
            payable(msg.sender).transfer(_balance); 
        } 
        else { 
            IERC20 erc20_ = IERC20(market.outputErc20); 
            erc20_.approve(msg.sender, _balance); 
        }
        return _balance; 
    }
}