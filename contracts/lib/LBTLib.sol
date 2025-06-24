// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.30;

import {Product, Period, Bond, ProtoProduct} from "../structs/BTStructs.sol";

library LBTLib { 

    function remove(uint256 [] memory _a, uint256 _b) internal pure returns (uint256 [] memory _c){
        uint256 y_ = 0;
        for(uint256 x_ = 0; x_ < _a.length; x_++){
            if(_a[x_] != _b){
                _c[y_] = _a[x_]; 
                y_++;
            }
        }
        return _c; 
    }


    function remove(address [] memory _a, address _b) internal pure returns (address [] memory _c){
        uint256 y_ = 0;
        for(uint256 x_ = 0; x_ < _a.length; x_++){
            if(_a[x_] != _b){
                _c[y_] = _a[x_]; 
                y_++;
            }
        }
        return _c; 
    }

    function getCoverage(Product memory  _product) internal pure returns (uint256 _coverage) {
        uint256 maxNumberOfPayouts = _product.term.max / LBTLib.resolvePeriod(_product.payoutInterval); 
        uint256 maximumMinPayoutAmount = ( _product.yield.min * _product.investmentPrincipal.max)/100;
        _coverage = maxNumberOfPayouts * maximumMinPayoutAmount; 
        return _coverage; 
    }

    function getCoverage(ProtoProduct memory _pProduct) internal pure returns (uint256 _coverage) {
        uint256 maxNumberOfPayouts = _pProduct.term.max / LBTLib.resolvePeriod(_pProduct.payoutInterval); 
        uint256 maximumMinPayoutAmount = ( _pProduct.yield.min * _pProduct.investmentPrincipal.max)/100;
        _coverage = maxNumberOfPayouts * maximumMinPayoutAmount; 
        return _coverage; 
    }

    function hasValidCoverage(Bond memory _bond, ProtoProduct memory _pProduct) internal pure returns (bool _isValid){
       uint256 requiredCoverage_ = getCoverage(_pProduct) * _pProduct.inventory;
        return _bond.coverage >= requiredCoverage_; 
    }

    function resolvePeriod(Period _period) internal pure returns (uint256 _time) {
        _time =  24 * 60 * 60;
        if(_period == Period.DAY) {
            return _time; 
        }
            _time *= 7; 
        if(_period == Period.WEEK) {
            return _time; 
        }
            _time *=  4; 
        if(_period == Period.MONTH) {
            return _time; 
        }
            _time *=  3;
        if(_period == Period.QUARTER) {
            return _time; 
        }
        _time *= 2;
        if(_period == Period.HALF) {
            return _time; 
        }
        _time *= 2; 
        if(_period == Period.YEAR) {
            return _time; 
        }
        return _time; 
    }   

    function resolveYieldSplit(Product memory _product, uint256 _yieldAmount, uint256 _investedAmount) internal pure returns (uint256 _fundReturn, uint256 _productFee, uint256 _treasurerReturn){
        uint256 maxYieldAmount_ = (_product.yield.max * _investedAmount)/100; 
        _fundReturn += _investedAmount; 

        _productFee = (_product.treasurerFee * _investedAmount)/100; 
        if(_yieldAmount >= maxYieldAmount_) {
            _fundReturn += maxYieldAmount_; 

            uint256 yieldSurplus_ = _yieldAmount - maxYieldAmount_; 
            if(yieldSurplus_ >= _productFee){
                _treasurerReturn = yieldSurplus_ - _productFee; 
            }
            else { 
                _productFee = yieldSurplus_; // no treasurer return 
                _treasurerReturn = 0; 

            }
        }
        else { 
            uint256 minYieldAmount_ = (_product.yield.min * _investedAmount)/100;
            if(_yieldAmount >= minYieldAmount_){
                _fundReturn += minYieldAmount_; 

                uint256 yieldSurplus_ = _yieldAmount - minYieldAmount_;
                if(yieldSurplus_ >= _productFee){
                    _treasurerReturn = yieldSurplus_ - _productFee; 
                }
                else {
                    _productFee = yieldSurplus_;
                    _treasurerReturn = 0; 
                }
            }
            else {
                _fundReturn += _yieldAmount; // everything goes to the fund 
                _productFee = 0; 
                _treasurerReturn = 0; 
            }
        }
        return (_fundReturn, _productFee, _treasurerReturn); 
    }


    
}