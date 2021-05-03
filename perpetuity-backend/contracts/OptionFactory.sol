//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.3;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Option.sol";

contract OptionFactory is Ownable {

    struct Auction {
        string asset;
        bool isCall;
        uint assetAmount;
        uint reservePrice;
        uint creationTime;
        uint duration;
        uint strikePrice;
        address owner;
        uint currentBid;
        address currentBidder;
    }

    Auction[] public auctions;
    address[] optionContracts;


    function createAuction(string _asset,
                           uint _reservePrice,
                           uint _assetAmount,
                           uint _duration,
                           uint _strikePrice,
                           bool _isCall) public {
        Auction memory newAuction = Auction({
            asset: _asset,
            assetAmount: _assetAmount,
            reservePrice: _reservePrice,
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
        //in order for the bid to be placed, we need to have the user approve
        // the approval will have to be for the superfluid token
        // ** place approval logic here **
        Auction storage auction = auctions[_auctionID];
        require(_amount > auction.currentBid, "Bid must be higher than current bid!");
        require(block.timestamp < auction.creationTime + auction.duration, "Auction is expired.");
        auction.currentBid = _amount;
        auction.currentBidder = msg.sender;
    }

    function createOption(uint _auctionID) public {
        Auction memory auction = auctions[_auctionID];
        require(msg.sender == auction.owner, "You are not the owner!");
        require(block.timestamp > auction.creationTime + auction.duration, "Auction is not yet over, please wait until after to create option");
        require(auction.currentBidder != address(0) && auction.currentBid > 0, "There are no bidders for the option!");
        require(auction.currentBid >= auction.reservePrice, "Reserve price was not met.");
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