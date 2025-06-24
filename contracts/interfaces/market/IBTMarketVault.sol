// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.30;


interface IBTMarketVault {

    function getMarketId() view external returns (uint256 _marketId); 

    function getPositionIds() view external returns (uint256 [] memory _positionIds);

    function getBalance(uint256 _positionId) view external returns (uint256 _balance);

    function depositBalance(uint256 _position, uint256 _balance) payable external returns (uint256 _totolBalance); 

    function withdrawBalance(uint256 _position) external returns (uint256 _balance); 


}