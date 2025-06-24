// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.30;

interface IBTRegister { 

    function isKnownAddress(address _address) view external returns (bool _isKnown);

    function getAddress(string memory _name) view external returns (address _address);

    function getName(address _address) view external returns (string memory _name);

}