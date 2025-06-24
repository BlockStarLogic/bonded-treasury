// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.30;

import {Fund} from "../../structs/BTStructs.sol";

interface IBTFundVaultFactory { 

    function isKnownVault(address _vault) view external returns (bool _isKnown);

    function getFundVault(uint256 _fundId) external returns (address _fundVault); 
}