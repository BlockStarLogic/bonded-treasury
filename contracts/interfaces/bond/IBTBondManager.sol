// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.30;

import {Range, Bond, BondSettlement, BondType} from "../../structs/BTStructs.sol";

interface IBTBondManager { 

    function getBondIds() view external returns (uint256 [] memory _bondIds);

    function getBond(uint256 _bondId) view external returns (Bond memory _bond);

    function getSettlement(uint256 _settlementId) view external returns (BondSettlement memory _settlement); 

    function createBond(address _owner, string memory _name, address _erc20, uint256 _amount, Range memory _consumptionPerUser, BondType _bondType) payable external returns (uint256 _bondId);

    function consumeCoverage(uint256 _bondId, address _consumer, uint256 _amount) external returns (uint256 _consumptionIndex);

    function releaseCoverage(uint256 _bondId, uint256 _consumptionIndex) external returns (bool _released);

    function requestCompensation(uint256 _bondId, uint256 _consumptionIndex, uint256 _amount) external returns (uint256 _settlementId);

    function topupBond(uint256 _bondId, uint256 _amount) external payable returns (uint256 _topUpId);

    function releaseBond(uint256 _bondId) external returns (bool _closed); 
}