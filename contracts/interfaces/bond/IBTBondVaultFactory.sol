// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.30;

import {Bond} from "../../structs/BTStructs.sol";

interface IBTBondVaultFactory { 

    function isKnownVault(address _address) view external returns (bool _isKnown);

    function getBondVault(uint256 _bondId, address _bondToken) external returns (address _vault);
}