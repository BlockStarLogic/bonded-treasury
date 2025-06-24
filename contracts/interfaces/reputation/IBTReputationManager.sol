// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.30;

import {TreasurerStatus, BanRequest, Membership} from "../../structs/BTStructs.sol";

interface IBTReputationManager {

    function getMembership(uint256 membershipId) view external returns (Membership memory _membership); 

    function requestProductTreasurerMembership(uint256 _productId) external returns (uint256 _membershipId); 
    
    function removeProductTreasurerMembership(uint256 _membershipId) external returns (bool _removed);

    function isMember(uint256 _productId, address _address) view external returns (bool _isMember); 

    function getMemberStatus(uint256 _productId, address _address) view external returns (TreasurerStatus _status);

    function hasBans(address _member) view external returns (bool _hasBans); 

    function getBanRequests(address _member) view external returns (uint256 [] memory _banRequestId ); 

    function getBanRequest(uint256 _banRequestId) view external returns (BanRequest memory _request); 

    function requestMemberBan(uint256 _productId, uint256 _fundId, address _member, address _erc20, uint256 _expected, uint256 _actual) external returns (bool _acknowledged);

    function removeBanRequest(uint256 _banRequestId) payable external returns (bool _removed);

}