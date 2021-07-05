//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "./BTCConsumer.sol";
import "./ETHConsumer.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./OptionFactory.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract AuctionFactory is Ownable {

    using SafeMath for uint256;

    struct Auction {
        string asset;
        bool isCall;
        bool optionCreated;
        uint256 assetAmount;
        uint256 creationTime;
        uint256 duration;
        uint256 strikePrice;
        address owner;
        uint256 currentBid;
        address currentBidder;
    }

    Auction[] auctions;
    BTCConsumer btcOracle;
    ETHConsumer ethOracle;
    address maticWETH = 0xE8F3118fDB41edcFEF7bF1DCa8009Fa8274aa070;
    address maticWBTC = 0x90ac599445B07c8aa0FC82248f51f6558136203D;
    address maticDAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    address private optionFactoryAddress;
    IERC20 erc;
    OptionFactory factory;


    constructor(address _BTCoracle, address _ETHoracle) Ownable() {
        btcOracle = BTCConsumer(_BTCoracle);
        ethOracle = ETHConsumer(_ETHoracle);
    }

     modifier strikeSanityCheck(
        string memory _asset,
        bool _isCall,
        uint256 _strikePrice
    ) {
        require(
            stringsEqual(_asset, "WETH") || stringsEqual(_asset, "WBTC")
        );
        int256 price;
        if (stringsEqual(_asset, "WBTC")) {
            btcOracle.requestPriceData();
            price = btcOracle.price();
        } else {
            ethOracle.requestPriceData();
            price = ethOracle.price();
        }
        if (_isCall && _strikePrice > uint256(price)) _;
        else if (!_isCall && _strikePrice < uint256(price)) _;
    }

    modifier notOwner(uint256 _auctionID) {
        require(msg.sender != auctions[_auctionID].owner);
        _;
    }

    function setFactory(address _factory) onlyOwner() external {
        optionFactoryAddress = _factory;
    }

    function createAuction(
        string memory _asset,
        uint256 _reservePrice,
        uint256 _assetAmount,
        uint256 _duration,
        uint256 _strikePrice,
        bool _isCall
    ) external strikeSanityCheck(_asset, _isCall, _strikePrice) {
        require(_reservePrice > 0);
        require(_duration >= 3);
        address assetAddress = stringsEqual(_asset, "WETH")
            ? maticWETH
            : maticWBTC;
        uint256 amount = _isCall ? _assetAmount : _assetAmount.mul(_strikePrice);
        erc = _isCall ? IERC20(assetAddress) : IERC20(maticDAI);
        require(erc.balanceOf(msg.sender) >= amount);
        factory = OptionFactory(optionFactoryAddress);
        if (_isCall) factory.assetLockup(amount, assetAddress, msg.sender);
        else factory.assetLockup(amount, maticDAI, msg.sender);
        auctions.push(
            Auction({
                asset: _asset,
                assetAmount: _assetAmount,
                optionCreated: false,
                isCall: _isCall,
                creationTime: block.timestamp,
                duration: _duration,
                strikePrice: _strikePrice,
                owner: msg.sender,
                currentBid: _reservePrice,
                currentBidder: address(0)
            })
        );
    }

    function placeBid(uint256 _amount, uint256 _auctionId)
        external
        notOwner(_auctionId)
    {
        Auction storage auction = auctions[_auctionId];
        require(_amount > auction.currentBid);
        require(block.timestamp < auction.creationTime + auction.duration * 1 days);
        auction.currentBid = _amount;
        auction.currentBidder = msg.sender;
    }

    function completeAuction(uint256 _auctionId) external {
        Auction storage auction = auctions[_auctionId];
        require(!auction.optionCreated);
        auction.optionCreated = true;
    }

    function getAuctionInfo(uint256 _auctionId) 
        external 
        view 
        returns (Auction memory auction) {
        auction = auctions[_auctionId];
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