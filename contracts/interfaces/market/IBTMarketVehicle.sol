// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.30;

import {Position, MarketSettlement, VehicleType, VehicleStatus, MarketType} from "../../structs/BTStructs.sol"; 

interface IBTMarketVehicle {

    function getVehicleStatus() view external returns (VehicleStatus _vehicleStatus); 

    function getVehicleType () view external returns (VehicleType _vehicleType); 

    function getSupportedMarketType() view external returns (MarketType _marketType);

    function getMarketIds() view external returns (uint256 [] memory _marketIds); 

    function getPositionIds() view external returns (uint256 [] memory _positionId); 

    function getSettlement(uint256 _settlementId) view external returns (MarketSettlement memory _settlement); 

    function getPosition(uint256 _positionId) view external returns (Position memory _position); 

    function openPosition(address _owner, address _treasurer, uint256 _marketId, uint256 _amount) payable external returns (uint256 _position);

    function closePosition(uint256 _position) external returns (uint256 _settlementId); 

    function flushMarket(uint256 marketId) external returns (uint256 _marketBalance, uint256 _issuedCompensation); 
}