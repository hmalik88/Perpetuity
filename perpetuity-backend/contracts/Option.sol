//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;


import "../node_modules/hardhat/console.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Option is ERC721Burnable() {

  using SafeMath for uint;

    string public asset;
    address assetAddress;
    address maticDAI = 0x8Cab8846eE3eF1Cb5b71e87b8997DA8B24640981;
    uint256 assetAmount;
    uint256 public strikePrice;
    bool isCall;
    uint256 public flowRate;
    address initialOptionHolder;
    address optionWriter;
    uint256 optionId;
    uint256 paymentAmount;

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
    )
    ERC721("Perpetuity Option", "PERPO")
     {
        asset = _asset;
        assetAddress = _assetAddress;
        assetAmount = _assetAmount;
        strikePrice = _strikePrice;
        isCall = _isCall;
        flowRate = _flowRate;
        optionWriter = _optionWriter;
        optionId = _optionId;
        initialOptionHolder = _initialOptionHolder;
        paymentAmount = strikePrice.mul(assetAmount);
        _safeMint(_initialOptionHolder, _optionId);
    }

    function optionType() public view returns (string) {
        return isCall ? "Call" : "Put";
    }

    //functions to execute the option
    // option should be holding custody of the WETH/WBTC
    function executeOption() public {
        require(_isApprovedOrOwner(_msgSender(), optionId), "ERC721Burnable: caller is not owner nor approved");
        if (isCall) executeCall();
        else executePut();
        burn(optionId);
    }

    /**
     * @dev Internal function to execute a call option
     *
     * */
    function executeCall() internal {
        IERC20 erc;
        erc = IERC20(maticDAI);
        require(erc.balanceOf(msg.sender) >= paymentAmount, "Not enough DAI to execute call option");
        _transferOptionPaymentOrAsset(optionWriter, maticDAI, paymentAmount);
        _transferOptionAssetOrCollateral(msg.sender, assetAddress, assetAmount);
    }

    /**
     * @dev Internal function to execute a put option
     *
     * */
    function executePut() internal {
        IERC20 erc;
        erc = IERC20(assetAddress);
        require(erc.balanceOf(msg.sender) >= assetAmount, "Not enough option asset to execute put option");
        _transferOptionPaymentOrAsset(optionWriter, assetAddress, assetAmount);
        _transferOptionAssetOrCollateral(msg.sender, maticDAI, paymentAmount);
    }

    /**
     * @dev Internal function to transfer ERC20 held in the contract
     *
     * */
    function _transferOptionAssetOrCollateral(
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


    /**
     * @dev Internal function to transfer option call payment form option holder to option creator
     *
     * */
    function _transferOptionPaymentOrAsset(
        address _recipient,
        address _tokenContract,
        uint256 _paymentAmount
    )
        internal
    {
        IERC20 erc;
        erc = IERC20(_tokenContract);
        uint256 allowance = erc.allowance(_msgSender(), address(this));
        require(allowance >= _paymentAmount, "Token allowance not enough");
        require(erc.transferFrom(_msgSender(), _recipient, _paymentAmount), "Transfer failed");
    }
}
