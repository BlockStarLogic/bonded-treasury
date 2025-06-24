// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.30;

interface IBTIndex { 

    function isKnownIndex(uint256 _index) view external returns (bool _isKnown);

    function getIndex() external returns (uint256 _index);

}