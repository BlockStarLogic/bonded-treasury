// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.30;

import {ProtoInvestment, Investment, Divestment} from "../../structs/BTStructs.sol"; 

interface IBTTreasury { 

    function getInvestmentIds() view external returns (uint256 [] memory _investmentIds); 

    function getInvestment(uint256 _investmentId) view external returns (Investment memory _investment); 

    function getDivestmentByInvestmentId(uint256 _investmentId) view external returns (Divestment memory _divestment);  

    function getDivestment(uint256 _divestmentId) view external returns (Divestment memory _divestment);

    function invest(ProtoInvestment memory _investment) external returns (uint256 _investmentId); 

    function divest(uint256 _investmentId) external returns (uint256 _divestmetId); 
   
}