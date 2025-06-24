// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.30;

interface IBTVersion {

    function getName() view external returns (string memory _name);

    function getVersion() view external returns (uint256 _version);
}