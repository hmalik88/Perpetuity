//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC721/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
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
    address factoryAddress;

    mapping (uint256 => address) private _tokenApprovals;
    

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
        factoryAddress = msg.sender;
        _safeMint(_initialOptionHolder, _optionId);
    }

    modifier strikeSanityCheck(
        bool _isCall,
        uint256 _strikePrice
    ) {
        int256 price;
        if (stringsEqual(asset, "WBTC")) {
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

    function burn(uint256 tokenId) public override virtual {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId) || 
            msg.sender == factoryAddress, 
            "ERC721Burnable: caller is not owner nor approved"
        );
        _burn(tokenId);
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
        strikeSanityCheck(isCall, strikePrice)
    {
        IERC20 erc = IERC20(maticDAI);
        require(
            erc.balanceOf(msg.sender) >= paymentAmount,
            "INSUFFICIENT DAI TO EXECUTE CALL"
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
        strikeSanityCheck(isCall, strikePrice)
    {
        IERC20 erc = IERC20(assetAddress);
        require(
            erc.balanceOf(msg.sender) >= assetAmount,
            "INSUFFICIENT ASSETS TO EXECUTE PUT"
        );
        _transferOptionPaymentOrAsset(optionWriter, assetAddress, assetAmount);
        _transferOptionAssetOrCollateral(msg.sender, maticDAI, paymentAmount);
    }


    function recoverAssets(address _asset, uint256 _amount) external {
        require(msg.sender == factoryAddress, "CAN ONLY BE CALLED BY FACTORY");
        IERC20 returnToken = IERC20(_asset);
        returnToken.transfer(optionWriter, _amount);
        burn(optionId);
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
        IERC20 erc = IERC20(_tokenContract);
        require(
            erc.balanceOf(address(this)) >= _returnAmount,
            "INSUFFICIENT FUNDS"
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
        IERC20 erc = IERC20(_tokenContract);
        uint256 allowance = erc.allowance(_msgSender(), address(this));
        require(allowance >= _paymentAmount, "INSUFFICIENT ALLOWANCE");
        require(
            erc.transferFrom(_msgSender(), _recipient, _paymentAmount),
            "TRANSFER FAILED"
        );
    }

    /**
     * @dev Internal function to compare strings
     *
     * */
    function stringsEqual(string memory _a, string memory _b)
        internal
        pure
        returns (bool)
    {
        return (keccak256(abi.encodePacked((_a))) ==
            keccak256(abi.encodePacked((_b))));
    }
}
