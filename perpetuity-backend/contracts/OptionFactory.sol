//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.3;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Option.sol";
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

    IERCO underlyingToken;
    address maticWETH = 0xE8F3118fDB41edcFEF7bF1DCa8009Fa8274aa070;
    address maticWBTC = 0x90ac599445B07c8aa0FC82248f51f6558136203D;
    Auction[] public auctions;
    address[] optionContracts;


    function createAuction(string _asset,
                           uint _reservePrice,
                           uint _assetAmount,
                           uint _duration,
                           uint _strikePrice,
                           bool _isCall) public {
        require(_asset == "WETH" || _asset == "WBTC", "supported ERC-20 coins are only WETH and WBTC at the moment");
        require(_reservePrice > 0, "reserve price must be a positive value");
        require(_duration >= 3, "duration of the auction must be atleast 3 days");
        // insert logic to disallow creation of the call if the strike price is lower than the current asset price 
        // insert logic to disallow creation of the put if the srike price is higher than the current asset price
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
        require(!auction.optionCreated, "this option was already written!");
        require(msg.sender == auction.owner, "You are not the owner!");
        require(block.timestamp > auction.creationTime + auction.duration * 1 days, "Auction is not yet over, please wait until after to create option");
        require(auction.currentBidder != address(0) && auction.currentBid > 0, "There are no bidders for the option!");
        require(auction.currentBid >= auction.reservePrice, "Reserve price was not met.");
        auction.optionCreated = true;
        address option = new Option(auction.asset,
                                    auction.assetAmount,
                                    auction.strikePrice,
                                    auction.isCall,
                                    auction.currentBid,
                                    auction.owner,
                                    auction.currentBidder);
        if (auction.asset == "WETH") {

        }
        
        optionContracts.push(option);
    }



    
}