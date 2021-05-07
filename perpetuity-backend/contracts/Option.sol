//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Option is ERC721Burnable {
    string asset;
    address assetAddress;
    address maticDAI = 0x8Cab8846eE3eF1Cb5b71e87b8997DA8B24640981;
    uint256 assetAmount;
    uint256 strikePrice;
    bool isCall;
    uint256 flowRate;
    address initialOptionHolder;
    address optionWriter;
    uint256 optionId;

    constructor(
        string memory _asset,
        address _assetAddress,
        uint256 _assetAmount,
        uint256 _strikePrice,
        bool _isCall,
        uint256 _flowRate,
        address _optionWriter,
        address _initialOptionHolder,
        uint256 _optionId
    ) {
        asset = _asset;
        assetAddress = _assetAddress;
        assetAmount = _assetAmount;
        strikePrice = _strikePrice;
        isCall = _isCall;
        flowRate = _flowRate;
        optionWriter = _optionWriter;
        optionId = _optionId;
        initialOptionHolder = _initialOptionHolder;
        _safeMint(_initialOptionHolder, _optionId);
    }

    function underlyingAsset() public view returns (memory string) {
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
        if (isCall) executeCall();
        else executePut();
    }

    function executeCall() internal {
        require(_isApprovedOrOwner(_msgSender(), optionId), "ERC721Burnable: caller is not owner nor approved");
        _transferErc20(msg.sender, assetAddress, assetAmount);
        _transferErc20(optionWriter, maticDAI, assetAmount * strikePrice);
        burn(optionId);
    }

     function executePut() internal {
        require(_isApprovedOrOwner(_msgSender(), optionId), "ERC721Burnable: caller is not owner nor approved");
        _transferErc20(msg.sender, maticDAI, assetAmount * strikePrice);
        _transferErc20(optionWriter, assetAddress, assetAmount);
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
