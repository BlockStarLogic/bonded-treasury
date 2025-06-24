// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.30;

import "../../interfaces/bond/IBTBondVault.sol"; 
import "../../interfaces/util/IBTVersion.sol";
import "../../interfaces/util/IBTRegister.sol"; 

import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; 


contract BTBondVault is IBTBondVault, IBTVersion { 

    modifier bondManagerOnly () { 
        require(msg.sender == register.getAddress(BOND_MANAGER_CA), "bond manager only"); 
        _;
    }

    string constant name = "BT_BOND_VAULT"; 
    uint256 constant version = 1;

    string constant BOND_MANAGER_CA = "RESERVED_BOND_MANAGER"; 

    address constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE; 
    address immutable self;  

    IBTRegister register; 
    uint256 bondId; 
    IERC20 bondToken; 
    bool native; 

    constructor(address _register, uint256 _bondId, address _bondToken) { 
        register = IBTRegister(_register); 
        bondId = _bondId; 
        if(_bondToken == NATIVE){
            native = true;
        }
        else {
            bondToken = IERC20(_bondToken); 
            native = true; 
        }
    }

    function getName() pure external returns (string memory _name){
        return name; 
    }

    function getVersion() pure external returns (uint256 _version){
        return version; 
    }

    function getBondId() view external returns (uint256 _bondId){
        return bondId; 
    }

    function store(uint256 _amount) payable bondManagerOnly external returns (bool _stored){
        if(native){ 
            require(msg.value >= _amount, "insufficient amount transmitted"); 
        }
        else { 
            bondToken.transferFrom(msg.sender, self, _amount); 
        }
        return true;
    }

    function retrieve(uint256 _amount) external bondManagerOnly returns (bool _retrieved){
        return transferOut(_amount); 
    }

    function close() external bondManagerOnly returns (uint256 _balance){
        if(native) {
            _balance = self.balance;
        }
        else {
            _balance = bondToken.balanceOf(self);
        }
        transferOut(_balance);
        return _balance; 
    }

    // =========================== INTERNAL ========================================

    function transferOut(uint256 _amount) internal returns (bool _transferred) {
        if(native) {
            payable(msg.sender).transfer(_amount); 
        }
        else { 
            bondToken.approve(msg.sender, _amount); 
        }
        return true; 
    }

}