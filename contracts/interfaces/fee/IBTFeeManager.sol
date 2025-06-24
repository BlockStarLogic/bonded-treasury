// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.30;

import {Fee} from "../../structs/BTStructs.sol";

interface IBTFeeManager { 

    function getFee(string memory _name) view external returns (Fee memory _fee);

}