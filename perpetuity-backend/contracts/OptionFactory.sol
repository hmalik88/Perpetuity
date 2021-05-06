//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.3;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Option.sol";
import "./BTCConsumer.sol";
import "./ETHConsumer.sol";
import "@openzeppelin/contracts/token/ERC20/IERC2O.sol";

contract OptionFactory is Ownable {

    struct Auction {
        string asset;
        bool isCall;
        bool optionCreated;
        uint assetAmount;
        uint reservePrice;
        uint creationTime;
        uint duration;
        uint strikePrice;
        address owner;
        uint currentBid;
        address currentBidder;
    }

    address maticWETH;
    address maticWBTC;
    BTCConsumer btcOracle;
    ETHConsumer ethOracle;
    address ETHoracle;
    Auction[] public auctions;
    address[] optionContracts;

    constructor(address _BTCoracle, address _ETHoracle) public Ownable() {
        maticWETH = 0xE8F3118fDB41edcFEF7bF1DCa8009Fa8274aa070;
        maticWBTC = 0x90ac599445B07c8aa0FC82248f51f6558136203D;
        btcOracle = BTCConsumer(_BTCoracle);
        ethOracle = ETHConsumer(_ETHoracle);
    }

    modifier strikeSanityCheck(string _asset, bool _isCall, uint _strikePrice) {
        require(_asset == "WETH" || _asset == "WBTC", "supported ERC-20 coins are only WETH and WBTC at the moment");
        int256 price;
        if (_asset == "WBTC") {
            btcOracle.requestPriceData();
            price = btcOracle.price();
        } else {
            ethOracle.requestPriceData();
            price = ethOracle.price();
        }
        if (_isCall && _strikePrice > price) _;
        else if (!_isCall && _strikePrice < price) _;
    }

    function createAuction(string _asset,
                           uint _reservePrice,
                           uint _assetAmount,
                           uint _duration,
                           uint _strikePrice,
                           bool _isCall) public strikeSanityCheck(_asset, _isCall, _strikePrice) {
        require(_reservePrice > 0, "reserve price must be a positive value");
        require(_duration >= 3, "duration of the auction must be atleast 3 days");
        Auction memory newAuction = Auction({
            asset: _asset,
            assetAmount: _assetAmount,
            reservePrice: _reservePrice,
            optionCreated: false,
            isCall: _isCall,
            creationTime: block.timestamp,
            duration: _duration,
            strikePrice: _strikePrice,
            owner: msg.sender,
            currentBid: 0,
            currentBidder: address(0)
        });
        auctions.push(newAuction);
    }

    function placeBid(uint _amount, uint _auctionID) public {
        // amount is per sec
        //in order for the bid to be placed, we need to have the user approve supertoken (???)
        // OR we might need to just check the balance of the bidder's superfluid token is atleast at a month...we can request for their to be a reserve duration in premium
        // ** place approval logic here **
        Auction storage auction = auctions[_auctionID];
        require(_amount > auction.currentBid, "Bid must be higher than current bid!");
        require(block.timestamp < auction.creationTime + auction.duration * 1 days, "Auction is expired.");
        auction.currentBid = _amount;
        auction.currentBidder = msg.sender;
    }

    function createOption(uint _auctionID) public {
        // we want to be able to have the CFA start when the writer creates the option.
        // reqire them to have a balance
        //create CFA between option owner and bidder
        // emit an event that our contract is created and start the flow with the sdk on the front end?
        Auction memory auction = auctions[_auctionID];
        int256 price;
        require(!auction.optionCreated, "this option was already written!");
        require(msg.sender == auction.owner, "You are not the owner!");
        require(block.timestamp > auction.creationTime + auction.duration * 1 days, "Auction is not yet over, please wait until after to create option");
        require(auction.currentBidder != address(0) && auction.currentBid > 0, "There are no bidders for the option!");
        require(auction.currentBid >= auction.reservePrice, "Reserve price was not met.");
        auction.optionCreated = true;
        // need to check again if price makes sense with strike
        if (auction.asset == "WBTC") {
            btcOracle.requestPriceData();
            price = btcOracle.price();
        } else {
            ethOracle.requestPriceData();
            price = btcOracle.price();
        }
        require(auction.isCall ? price < auction.strikePrice : price > auction.strikePrice);
        address option = new Option(auction.asset,
                                    auction.assetAmount,
                                    auction.strikePrice,
                                    auction.isCall,
                                    auction.currentBid,
                                    auction.owner,
                                    auction.currentBidder);
        optionContracts.push(option);
    }



    
}