//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

contract Option is ERC721Burnable {
    string asset;
    address assetAddress;
    uint256 assetAmount;
    uint256 strikePrice;
    bool isCall;
    uint256 flowRate;
    address initialOptionHolder;
    address optionWriter;
    uint256 optionId;

    constructor(
        string _asset,
        address _assetAddress,
        uint256 _assetAmount,
        uint256 _strikePrice,
        bool _isCall,
        uint256 _flowRate,
        address _optionWriter,
        address _initialOptionHolder,
        uint256 optionId
    ) {
        asset = _asset;
        assetAddress = _assetAddress;
        assetAmount = _assetAmount;
        strikePrice = _strikePrice;
        isCall = _isCall;
        flowRate = _flowRate;
        optionWriter = _optionWriter;
        initialOptionHolder = _initialOptionHolder;
        _safeMint(_initialOptionHolder, optionId);
    }

    function underlyingAsset() public view returns (string) {
        return asset;
    }

    function strikePrice() public view returns (uint256) {
        return strikePrice;
    }

    function optionType() public view returns (string) {
        return isCall ? "Call" : "Put";
    }

    function flowRate() public view returns (uint256) {
        return flowRate;
    }

    //functions to execute the option
    // option should be holding custody of the WETH/WBTC
    function executeOption() public {
        require(_isApprovedOrOwner(_msgSender(), optionId), "ERC721Burnable: caller is not owner nor approved");
        _transferErc20(msg.sender, assetAddress, assetAmount);
        burn(optionId);
    }


    /**
     * @dev Internal function to transfer ERC20 held in the contract
     *
     * */
    function _transferErc20(
        address _recipient,
        address _tokenContract,
        uint256 _returnAmount
    ) 
        internal
    {
        IERC20 erc;
        erc = IERC20(_tokenContract);
        require(erc.balanceOf(address(this)) >= _returnAmount, "Not enough funds to transfer");
        erc.transfer(_recipient, _returnAmount);
    }
}
