// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.30;

import "../../../interfaces/market/IBTMarketManager.sol";
import "../../../interfaces/market/IBTMarketVehicle.sol"; 
import "../../../interfaces/util/IBTVersion.sol";
import "../../../interfaces/util/IBTRegister.sol"; 
import "../../../interfaces/util/IBTIndex.sol"; 



contract BTUniswapMarketVehicle is IBTVersion, IBTMarketVehicle { 


    string constant name = "RESERVED_BT_MARKET_VEHICLE_UNISWAP"; 
    uint256 constant version = 1; 

    address constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE; 

    string constant INDEX_CA = "RESERVED_BT_INDEX"; 
    string constant MARKET_VAULT_FACTORY_CA = "RESERVED_BT_MARKET_VAULT_FACTORY"; 
    string constant ADMIN_CA = "RESERVED_BT_ADMIN"; 

    string constant FEE_MANAGER_CA = "RESERVED_FEE_MANAGER";
    string constant FEE_WALLET_CA = "RESERVED_FEE_WALLET"; 

    address immutable self; 

    VehicleType vehicleType;
    IBTRegister register; 
    VehicleStatus status; 

    constructor(address _register, VehicleType _vehicleType) { 
        register = IBTRegister(_register); 
        vehicleType = _vehicleType; 
    }

    function getName() pure external returns (string memory _name){
        return name; 
    }

    function getVersion() pure external returns (uint256 _version){
        return version; 
    }

    function getVehicleStatus() view external returns (VehicleStatus _vehicleStatus){
        return status; 
    }

    function getVehicleType () view external returns (VehicleType _vehicleType){ 
        return vehicleType;
    }

    function getSupportedMarketType() view external returns (MarketType _marketType){

    }

    function getMarketIds() view external returns (uint256 [] memory _marketIds){

    }

    function getPositionIds() view external returns (uint256 [] memory _positionId){

    }

    function getSettlement(uint256 _settlementId) view external returns (MarketSettlement memory _settlement){

    }

    function getPosition(uint256 _positionId) view external returns (Position memory _position){

    }

    function openPosition(address _owner, address _treasurer, uint256 _marketId, uint256 _amount) payable external returns (uint256 _position){

    }

    function closePosition(uint256 _position) external returns (uint256 _settlementId){

    } 

    function flushMarket(uint256 marketId) external returns (uint256 _marketBalance, uint256 _issuedCompensation){
        
    } 

}