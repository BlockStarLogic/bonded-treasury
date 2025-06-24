// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.30;

import {ProtoProduct, Product, TreasurerStatus} from "../../structs/BTStructs.sol";

interface IBTProductManager {
    
    function getProductIds() view external returns (uint256 [] memory _productIds);

    function getProduct(uint256 _productId) view external returns (Product memory _product);

    function createProduct(ProtoProduct memory _pProduct) payable external returns (uint256 _productId);

    function procureProduct(uint256 _productId, address _purchaser) external returns (uint256 _productIndex, uint256 _coverage, uint256 _consumptionIndex);

    function releaseProduct(uint256 _productId, uint256 _consumptionIndex, address _purchaser) external returns (bool _released);
    
    function expireProduct(uint256 _productId) external returns (bool _expired);

    function cancelProduct(uint256 _productId) external returns (bool _cancelled); 

}