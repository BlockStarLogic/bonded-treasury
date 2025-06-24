// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.30;

import {Fund, FundVaultStatus} from "../../structs/BTStructs.sol"; 

interface IBTFundVault { 

    function getVaultStatus() view external returns (FundVaultStatus _status);

    function getBalance() view external returns (uint256 _balance);

    function getFund() view external returns (Fund memory _fund); 

    function deposit(uint256 _amount) payable external returns (bool _acknowledged); 

    function withdraw(uint256 _amount) external returns (bool _acknowledged); 

    function pullFunds(address _treasurer) external returns (uint256 _productLimitedAmount);

    function pushFunds(uint256 _amount, address _treasurer) payable external returns (bool _acknowledged);

    function close() external returns (uint256 _balance); 

}