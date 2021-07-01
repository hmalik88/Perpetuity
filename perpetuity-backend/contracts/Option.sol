//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC721/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./BTCConsumer.sol";
import "./ETHConsumer.sol";

contract Option is ERC721Burnable {
    using SafeMath for uint256;

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
    BTCConsumer btcOracle;
    ETHConsumer ethOracle;

    constructor(
        string memory _asset,
        address _assetAddress,
        uint256 _assetAmount,
        uint256 _strikePrice,
        bool _isCall,
        uint256 _flowRate,
        address _optionWriter,
        address _initialOptionHolder,
        uint256 _optionId,
        address _btcOracle,
        address _ethOracle
    ) ERC721("Perpetuity Option", "PERPO") {
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
        btcOracle = BTCConsumer(_btcOracle);
        ethOracle = ETHConsumer(_ethOracle);
        _safeMint(_initialOptionHolder, _optionId);
    }

    modifier strikeSanityCheck(
        string _asset,
        bool _isCall,
        uint256 _strikePrice
    ) {
        require(
            stringsEqual(_asset, "WETH") || stringsEqual(_asset, "WBTC"),
            "supported ERC-20 coins are only WETH and WBTC at the moment"
        );
        int256 price;
        if (stringsEqual(_asset, "WBTC")) {
            btcOracle.requestPriceData();
            price = btcOracle.price();
        } else {
            ethOracle.requestPriceData();
            price = ethOracle.price();
        }
        if (_isCall && _strikePrice > uint(price)) _;
        else if (!_isCall && _strikePrice < uint(price)) _;
    }

    function optionType() public view returns (string memory) {
        return isCall ? "Call" : "Put";
    }

    //functions to execute the option
    // option should be holding custody of the WETH/WBTC
    function executeOption() public {
        require(
            _isApprovedOrOwner(_msgSender(), optionId),
            "ERC721Burnable: caller is not owner nor approved"
        );
        if (isCall) executeCall();
        else executePut();
        burn(optionId);
    }

    /**
     * @dev Internal function to execute a call option
     *
     * */
    function executeCall()
        internal
        strikeSanityCheck(asset, isCall, strikePrice)
    {
        IERC20 erc;
        erc = IERC20(maticDAI);
        require(
            erc.balanceOf(msg.sender) >= paymentAmount,
            "Not enough DAI to execute call option"
        );
        _transferOptionPaymentOrAsset(optionWriter, maticDAI, paymentAmount);
        _transferOptionAssetOrCollateral(msg.sender, assetAddress, assetAmount);
    }

    /**
     * @dev Internal function to execute a put option
     *
     * */
    function executePut()
        internal
        strikeSanityCheck(asset, isCall, strikePrice)
    {
        IERC20 erc;
        erc = IERC20(assetAddress);
        require(
            erc.balanceOf(msg.sender) >= assetAmount,
            "Not enough option asset to execute put option"
        );
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
    ) internal {
        IERC20 erc;
        erc = IERC20(_tokenContract);
        require(
            erc.balanceOf(address(this)) >= _returnAmount,
            "Not enough funds to transfer"
        );
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
    ) internal {
        IERC20 erc;
        erc = IERC20(_tokenContract);
        uint256 allowance = erc.allowance(_msgSender(), address(this));
        require(allowance >= _paymentAmount, "Token allowance not enough");
        require(
            erc.transferFrom(_msgSender(), _recipient, _paymentAmount),
            "Transfer failed"
        );
    }

    /**
     * @dev Internal function to compare strings
     *
     * */
    function stringsEqual(string memory _a, string memory _b)
        internal
        returns (bool)
    {
        return (keccak256(abi.encodePacked((_a))) ==
            keccak256(abi.encodePacked((_b))));
    }
}
