// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.30;

import {Market, ProtoMarket} from "../../structs/BTStructs.sol"; 

interface IBTMarketManager { 

    function getMarketIds() view external returns (uint256 [] memory _marketIds);

    function getMarket(uint256 _marketId) view external returns (Market memory _market); 

    function creatMarket(ProtoMarket memory _market ) payable external returns (uint256 _marketId); 

    function closeMarket(uint256 _marketId) external returns (bool _marketClosed); 
}