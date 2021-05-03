//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.3;

import "hardhat/console.sol";



contract Option {
  string asset;
  uint assetAmount;
  uint strikePrice;
  bool isCall;
  uint flowRate;
  address optionHolder;
  address optionWriter;

  constructor(string _asset,
              uint _assetAmount, 
              uint _strikePrice, 
              bool _isCall, 
              uint _flowRate,
              address _optionWriter,
              address _optionHolder) {
    asset = _asset;
    strikePrice = _strikePrice;
    isCall = _isCall;
    optionHolder = _optionHolder;
    optionWriter = _optionWriter;
    assetAmount = _assetAmount;
    flowRate = _flowRate;
  }

  function underlyingAsset() public view returns (string) {
    return asset;
  }

  function strikePrice() public view returns (uint) {
    return strikePrice;
  }

  function optionType() public view returns (string) {
    if (isCall == 1) return "Call";
    return "Put";
  }

  function flowRate() public view returns (uint) {
    return flowRate;
  }

}
