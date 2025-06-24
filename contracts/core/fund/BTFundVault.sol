// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.30;

import "../../interfaces/fund/IBTFundVault.sol";
import "../../interfaces/fund/IBTFundManager.sol";

import "../../interfaces/product/IBTProductManager.sol"; 
 
import "../../interfaces/reputation/IBTReputationManager.sol"; 

import "../../interfaces/util/IBTVersion.sol";
import "../../interfaces/util/IBTRegister.sol"; 

import "../../lib/LBTLib.sol"; 

import  {FundVaultStatus, ProductStatus, TreasurerStatus, Times} from "../../structs/BTStructs.sol"; 

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BTFundVault is IBTFundVault, IBTVersion { 

    modifier ownerOnly { 
         Fund memory fund_ = fundManager.getFund(fundId); 
        require(msg.sender == fund_.owner || msg.sender == register.getAddress(ADMIN_CA), "owner only ");
        _;
    }

    modifier permittedProductTreasurerOnly (address _treasurer) { 
        Fund memory fund_ = fundManager.getFund(fundId); 
        require((reputationManager.getMemberStatus(fund_.productId, _treasurer) == TreasurerStatus.PERMITTED) || msg.sender == register.getAddress(ADMIN_CA), "treasurer only"); 
        _;
    }

    modifier productTreasurerOnly (address _treasurer) { 
        Fund memory fund_ = fundManager.getFund(fundId); 
        require(reputationManager.isMember(fund_.productId, _treasurer) || msg.sender == register.getAddress(ADMIN_CA), "treasurer only"); 
        _;
    }

    modifier fundManagerOnly { 
        require(msg.sender == address(fundManager), "fund manager only "); 
        _; 
    }

    string constant name = "BT_FUND_VAULT"; 
    uint256 constant version = 1; 

    address constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    string constant ADMIN_CA = "RESERVED_BT_ADMIN"; 
    string constant TREASURER_CA = "RESERVED_BT_TREASURER";
    string constant PRODUCT_MANAGER_CA = "RESERVED_BT_PRODUCT_MANAGER"; 
    string constant FUND_MANAGER_CA = "RESERVED_BT_FUND_MANAGER"; 
    string constant REPUTATION_MANAGER_CA = "RESERVED_BT_REPUTATION_MANAGER"; 

    uint256 immutable fundId; 
    address immutable self; 

    FundVaultStatus status; 
    Times times; 
    uint256 vaultBalance; 
    uint256 expectedMinimumReturn; 
    bool inShutdown; 

    IBTRegister register; 
    IBTProductManager productManager; 
    IBTFundManager fundManager; 
    IBTReputationManager reputationManager; 

    constructor(address _register, uint256 _fundId) { 
        fundId = _fundId; 
        register = IBTRegister(_register); 
        self = address(this);
    }

    function getName() pure external returns (string memory _name){
        return name; 
    }

    function getVersion() pure external returns (uint256 _version){
        return version; 
    }

    function getVaultStatus() view external returns (FundVaultStatus _status){
        return status; 
    }

    function getBalance() view external returns (uint256 _balance){ 
        return vaultBalance; 
    }

    function getFund() view external returns (Fund memory _fund){
        return fundManager.getFund(fundId);
    }

    function getTimes() view external returns (Times memory _times){
        return times; 
    }

    function deposit(uint256 _amount) payable external returns (bool _acknowledged){
        require(status == FundVaultStatus.OPEN && !inShutdown, "invalid fund vault status"); 

        Fund memory fund_ = fundManager.getFund(fundId); 
        Product memory product_ = productManager.getProduct(fund_.productId); 
        require(product_.status == ProductStatus.AVAILABLE || product_.status == ProductStatus.SOLDOUT, "product unavailable"); 
        require(product_.expiryDate > block.timestamp, "product expired"); 
        require(_amount + vaultBalance >= product_.investmentPrincipal.min && _amount + vaultBalance<= product_.investmentPrincipal.max, "principal out of product bounds"); 
        vaultBalance += _amount;
    
        if(fund_.erc20 == NATIVE) {
            require(msg.value >= _amount, "invalid value transmitted"); 
        }
        else { 
            IERC20 erc20_ = IERC20(fund_.erc20); 
            erc20_.transferFrom(msg.sender, self, _amount); 
        }   
        return true; 
    }

    function withdraw(uint256 _amount) external ownerOnly returns (bool _acknowledged){
        require(status == FundVaultStatus.OPEN && !inShutdown, "invalid fund vault status"); 

        Fund memory fund_ = fundManager.getFund(fundId); 
        Product memory product_ = productManager.getProduct(fund_.productId);
        vaultBalance -= _amount; 
        require(vaultBalance >= product_.investmentPrincipal.min, "excessive withdrawal"); 
        if(fund_.erc20 == NATIVE) {
            payable(fund_.owner).transfer(_amount); 
        }
        else { 
            IERC20 erc20_ = IERC20(fund_.erc20); 
            erc20_.transfer(fund_.owner, _amount); 
        }  
        return true; 
    }

    function shutdown() external ownerOnly returns (bool _acknowledged) { 
        inShutdown = true; 
        return true; 
    }

    function pullFunds(address _treasurer) external permittedProductTreasurerOnly(_treasurer) returns (uint256 _productLimitedAmount){
        require(status == FundVaultStatus.OPEN && !inShutdown, "invalid fund vault status"); 
        require(block.timestamp >= times.nextPull, "insufficient wait time"); 

        times.lastPull = block.timestamp; 
        Fund memory fund_ = fundManager.getFund(fundId); 
        Product memory product_ = productManager.getProduct(fund_.productId);

        _productLimitedAmount = getProductLimitedAmountInternal(fund_, product_);
        expectedMinimumReturn = (_productLimitedAmount * product_.yield.min) / 100; 
        status = FundVaultStatus.IN_MARKET; 

        if(fund_.erc20 == NATIVE) {
            payable(msg.sender).transfer(_productLimitedAmount); 
        }
        else { 
            IERC20 erc20_ = IERC20(fund_.erc20); 
            erc20_.approve(msg.sender, _productLimitedAmount); 
        }  
        return _productLimitedAmount; 
    }

    function pushFunds(uint256 _amount, address _treasurer) payable external productTreasurerOnly(_treasurer) returns (bool _acknowledged){
        require(status == FundVaultStatus.IN_MARKET, "invalid fund vault status"); 
        
        times.lastPush = block.timestamp; 
        
        Fund memory fund_ = fundManager.getFund(fundId);
        times.nextPull = times.lastPush + LBTLib.resolvePeriod(productManager.getProduct(fund_.productId).payoutInterval);

        uint256 selfBalance_ = getSelfBalance(fund_.erc20); 
        
        vaultBalance = selfBalance_ + _amount; 
        if(expectedMinimumReturn > _amount) {
            status = FundVaultStatus.DAMAGED; 
            reputationManager.requestMemberBan(fund_.productId, fundId, _treasurer, fund_.erc20, expectedMinimumReturn, _amount);
        }
        else {
            status = FundVaultStatus.OPEN; 
        }
        
        if(fund_.erc20 == NATIVE) {
            require(msg.value >= _amount, "invalid value transmitted"); 
        }
        else { 
            IERC20 erc20_ = IERC20(fund_.erc20); 
            erc20_.transferFrom(msg.sender, self, _amount); 
        }   
        return true; 
    }

    function close() external fundManagerOnly returns (uint256 _balance){
        require(inShutdown && (status == FundVaultStatus.OPEN || status == FundVaultStatus.DAMAGED), "invalid vault state" );
        status = FundVaultStatus.CLOSED; 
        Fund memory fund_ = fundManager.getFund(fundId);
        _balance = getSelfBalance(fund_.erc20);
        if(fund_.erc20 == NATIVE) {
            payable(msg.sender).transfer(_balance); 
        }
        else { 
            IERC20 erc20_ = IERC20(fund_.erc20); 
            erc20_.approve(msg.sender, _balance); 
        }  
        return _balance; 
    } 

    //================================== INTENRAL ================================================

    function getSelfBalance(address _erc20) internal view returns (uint256 _balance) {
        if(_erc20 == NATIVE){
            _balance = self.balance; 
        }
        else {
            IERC20 erc20_ = IERC20(_erc20);
            _balance = erc20_.balanceOf(self); 
        }
        return _balance;
    }

    function getProductLimitedAmountInternal(Fund memory _fund, Product memory _product) internal view returns (uint256 _amount) {
        uint256 selfBalance_ = getSelfBalance(_fund.erc20); 
        if(selfBalance_  >= _product.investmentPrincipal.max){
            _amount = _product.investmentPrincipal.max; 
        }
        else {
            _amount = selfBalance_; 
        }
        return _amount;
    }
}