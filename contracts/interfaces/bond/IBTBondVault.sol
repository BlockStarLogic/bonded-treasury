// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.30;

interface IBTBondVault { 

    function getBondId() view external returns (uint256 _bondId);

    function store(uint256 _amount) payable external returns (bool _stored);

    function retrieve(uint256 _amount) external returns (bool _retrieved); 

    function close() external returns (uint256 _balance);

}