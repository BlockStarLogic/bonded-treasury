// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.30;

interface IBTMarketVaultFactory { 

    function getMarketVaults() view external returns (address[] memory _vaults); 

    function isKnownVault(address _address) view external returns (bool _isKnown);

    function getMarketVault(uint256 _marketId) external returns (address _marketVault); 
}