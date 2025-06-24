// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.30;

import "../../interfaces/product/IBTProductManager.sol"; 

import "../../interfaces/reputation/IBTReputationManager.sol"; 

import "../../interfaces/fund/IBTFundManager.sol"; 
import "../../interfaces/fund/IBTFundVault.sol"; 

import "../../interfaces/util/IBTVersion.sol";
import "../../interfaces/util/IBTRegister.sol"; 
import "../../interfaces/util/IBTIndex.sol"; 

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Membership, Fund, FundVaultStatus} from "../../structs/BTStructs.sol";

import "../../lib/LBTLib.sol"; 

contract  BTReputationManager is IBTReputationManager, IBTVersion { 

    using LBTLib for uint256[]; 

    string constant name = "RESERVED_BT_BOND_MANAGER"; 
    uint256 constant version = 1; 

    address constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE; 

    string constant INDEX_CA = "RESERVED_BT_INDEX"; 
    string constant FUND_MANAGER_CA = "RESERVED_BT_FUND_MANAGER"; 
    string constant PRODUCT_MANAGER_CA = "RESERVED_BT_PRODUCT_MANAGER"; 

    string constant EMBARGO_THRESHOLD = "EMBARGO"; 
    string constant BAN_THRESHOLD = "BAN"; 

    address immutable self;

    IBTRegister register; 
    IBTIndex index; 
    IBTFundManager fundManager; 
    IBTProductManager productManager; 

    mapping(string=>uint256) thresholdByName; 

    mapping(address=>mapping(uint256=>bool)) isMemberByProductIdByAddress;
    mapping(uint256=>mapping(address=>uint256)) membershipIdByMemberByProductId; 

    mapping(uint256=>uint256[]) productMembershipIdsByProductId;
    mapping(address=>uint256[]) productMembershipIdsByAddresss; 

    mapping(uint256=>Membership) membershipById; 

    mapping(address=>uint256[]) banRequestIdsByAddress; 
    mapping(uint256=>BanRequest) banRequestById; 

    constructor(address _register) {
        register = IBTRegister(_register); 
        index = IBTIndex(register.getAddress(INDEX_CA)); 
        fundManager = IBTFundManager(register.getAddress(FUND_MANAGER_CA)); 
        productManager = IBTProductManager(register.getAddress(PRODUCT_MANAGER_CA)); 
        thresholdByName[EMBARGO_THRESHOLD] = 1; 
        thresholdByName[BAN_THRESHOLD] = 3; 
    }

    function getName() pure external returns (string memory _name){
        return name; 
    }

    function getVersion() pure external returns (uint256 _version){
        return version; 
    }

    function getMembership(uint256 _membershipId) view external returns (Membership memory _membership){
        return membershipById[_membershipId];
    } 

    function requestProductTreasurerMembership(uint256 _productId) external returns (uint256 _membershipId ){
        require(!isMemberByProductIdByAddress[msg.sender][_productId], "already member"); 
        Product memory product_ = productManager.getProduct(_productId); 

        if(banRequestIdsByAddress[msg.sender].length > 0) {
            require(product_.bansAllowed, "bans not allowed for product"); 
        }
        isMemberByProductIdByAddress[msg.sender][_productId] = true; 
        _membershipId = index.getIndex();
        productMembershipIdsByProductId[_productId].push(_membershipId);
        productMembershipIdsByAddresss[msg.sender].push(_membershipId); 
        membershipIdByMemberByProductId[_productId][msg.sender] = _membershipId; 
        membershipById[_productId] = Membership({
                                                    id : _membershipId, 
                                                    member : msg.sender, 
                                                    productId : _productId,
                                                    status : TreasurerStatus.PERMITTED
                                                });
        return _membershipId; 
    }

    function removeProductTreasurerMembership(uint256 _membershipId) external returns (bool _removed) {
        Membership memory membership_ = membershipById[_membershipId];
        isMemberByProductIdByAddress[membership_.member][membership_.productId] = false; 
        productMembershipIdsByProductId[membership_.productId] = productMembershipIdsByProductId[membership_.productId].remove(_membershipId);
        productMembershipIdsByAddresss[membership_.member]= productMembershipIdsByAddresss[membership_.member].remove(_membershipId); 
        delete membershipIdByMemberByProductId[membership_.productId][membership_.member];
        membershipById[membership_.productId].status = TreasurerStatus.CANCELLED; 
        return true; 
    }

    function isMember(uint256 _productId, address _address) view external returns (bool _isMember){
        return isMemberByProductIdByAddress[_address][_productId]; 
    } 

    function getMemberStatus(uint256 _productId, address _address) view external returns (TreasurerStatus _status){
        return membershipById[membershipIdByMemberByProductId[_productId][_address]].status; 
    }

    function hasBans(address _member) view external returns (bool _hasBans){
        return hasBansInternal(_member); 
    } 

    function getBanRequests(address _member) view external returns (uint256 [] memory _banRequestId ){
        return banRequestIdsByAddress[_member]; 
    } 

    function getBanRequest(uint256 _banRequestId) view external returns (BanRequest memory _request){
        return banRequestById[_banRequestId]; 
    } 

    function requestMemberBan(uint256 _productId, uint256 _fundId, address _member, address _erc20, uint256 _expected, uint256 _actual) external returns (bool _acknowledged){
        uint256 banRequestId_ = index.getIndex();
        banRequestById[banRequestId_] = BanRequest({
                                                    id : banRequestId_,
                                                    productId : _productId,
                                                    fundId : _fundId,
                                                    member  : _member,
                                                    erc20 : _erc20,
                                                    expected : _expected, 
                                                    actual : _actual,
                                                    createDate : block.timestamp,
                                                    removeDate : 0
                                                   });
        banRequestIdsByAddress[_member].push(banRequestId_);

        uint256 membership_ = membershipIdByMemberByProductId[_productId][_member]; 
  
        return changeMembershipStatus(membership_, _member); 
    }

    function removeBanRequest(uint256 _banRequestId) payable external returns (bool _removed){
        BanRequest memory banRequest_ = banRequestById[_banRequestId]; 
        uint256 loss_ = banRequest_.expected - banRequest_.actual; 
        Fund memory fund_ = fundManager.getFund(banRequest_.fundId); 
        IBTFundVault vault_ = IBTFundVault(fund_.vault);
        if(banRequest_.erc20 == NATIVE){
            require(msg.value >= loss_, "insufficient value transmitted"); 
            if(vault_.getVaultStatus() == FundVaultStatus.OPEN){
                IBTFundVault(fund_.vault).deposit{value : loss_}(loss_);
            }
            else { 
                payable(fund_.owner).transfer(loss_); 
            }
            uint256 change_ = msg.value - loss_; 
            if(change_ > 0){
                payable(msg.sender).transfer(change_); 
            }
        }
        else { 
            IERC20 erc20_ = IERC20(banRequest_.erc20);
            if(vault_.getVaultStatus() == FundVaultStatus.OPEN){
                erc20_.approve(fund_.vault, loss_);
                IBTFundVault(fund_.vault).deposit(loss_);
            }
            else { 
                erc20_.transfer(fund_.owner, loss_); 
            }
        }
        return removeBanInternal(_banRequestId); 
    }

    function getThreshold(string memory _name) view external returns (uint256 _threshold) {
        return thresholdByName[_name]; 
    }

    function setThreshold(string memory _name, uint256 _threshold) external returns (bool _set){
        thresholdByName[_name] = _threshold;
        return true; 
    }

    //==================================== INTERNAL ============================================================
    function hasBansInternal(address _member) view internal returns (bool _hasBans){
        return banRequestIdsByAddress[_member].length > 0;
    }

    function removeBanInternal(uint256 _banRequestId) internal returns (bool _removed){
        banRequestById[_banRequestId].removeDate = block.timestamp; 
        address member_ = banRequestById[_banRequestId].member;
        banRequestIdsByAddress[member_] = banRequestIdsByAddress[member_].remove(_banRequestId); 

        uint256 membership_ = membershipIdByMemberByProductId[banRequestById[_banRequestId].productId][member_];
        return changeMembershipStatus(membership_, member_);
    }

    function changeMembershipStatus(uint256 _membership, address _member) internal returns (bool _statusChanged) {
        if(banRequestIdsByAddress[_member].length == 0){
            membershipById[_membership].status = TreasurerStatus.PERMITTED;
        }
        if(banRequestIdsByAddress[_member].length >= thresholdByName[EMBARGO_THRESHOLD]){
            membershipById[_membership].status = TreasurerStatus.EMBARGOED;
        }
        if(banRequestIdsByAddress[_member].length >= thresholdByName[BAN_THRESHOLD]){
            membershipById[_membership].status = TreasurerStatus.BANNED;
        }
        return true; 
    }
}