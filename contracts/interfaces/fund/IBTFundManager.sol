// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.30;

import {Fund} from "../../structs/BTStructs.sol"; 

interface IBTFundManager {   

    function getFund(uint256 _fundId) view external returns (Fund memory _fund);

    function getFundIdsByProductId(uint256 _productId) view external returns (uint256 [] memory _fundId);

    function createFund(string memory _name, address _owner, address _erc20, uint256 _amount, uint256 _productId) payable external returns (uint256 _fundId);
  
}