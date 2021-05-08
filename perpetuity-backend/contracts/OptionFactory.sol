//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "./Option.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";
import {
    ISuperfluid,
    ISuperToken,
    ISuperAgreement,
    SuperAppDefinitions
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

import {
    IConstantFlowAgreementV1
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";

import {
    SuperAppBase
} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperAppBase.sol";
import "./BTCConsumer.sol";
import "./ETHConsumer.sol";

contract OptionFactory is Ownable, SuperAppBase {

using SafeMath for uint;

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

    address maticWETH = 0xE8F3118fDB41edcFEF7bF1DCa8009Fa8274aa070;
    address maticWBTC = 0x90ac599445B07c8aa0FC82248f51f6558136203D;
    address maticDAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    address private BTCoracle;
    address private ETHoracle;
    BTCConsumer btcOracle;
    ETHConsumer ethOracle;

    ISuperfluid private host = ISuperfluid(0xEB796bdb90fFA0f28255275e16936D25d3418603);
    address private fdaiX = 0x5D8B4C2554aeB7e86F387B4d6c00Ac33499Ed01f;
    IConstantFlowAgreementV1 private cfa = IConstantFlowAgreementV1(0x49e565Ed1bdc17F3d220f72DF0857C26FA83F873);

    
    Auction[] public auctions;
    address[] optionContracts;

    constructor(address _BTCoracle, address _ETHoracle) public Ownable() {
        BTCoracle = _BTCoracle;
        ETHoracle = _ETHoracle;
        btcOracle = BTCConsumer(BTCoracle);
        ethOracle = ETHConsumer(ETHoracle);
        uint256 configWord =
            SuperAppDefinitions.APP_LEVEL_FINAL |
            SuperAppDefinitions.BEFORE_AGREEMENT_CREATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_UPDATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_TERMINATED_NOOP;

        host.registerApp(configWord);
    }

    modifier strikeSanityCheck(string _asset, bool _isCall, uint _strikePrice) {
        require(stringsEqual(_asset, "WETH") || stringsEqual(_asset, "WBTC"), "supported ERC-20 coins are only WETH and WBTC at the moment");
        int256 price;
        if (stringsEqual(_asset, "WBTC")) {
            btcOracle.requestPriceData();
            price = btcOracle.price();
        } else {
            ethOracle.requestPriceData();
            price = ethOracle.price();
        }
        if (_isCall && _strikePrice > price) _;
        else if (!_isCall && _strikePrice < price) _;
    }

    modifier notOwner(uint _auctionID) {
        require(msg.sender != auctions[auctionID].owner);
    }

    function createAuction(string memory _asset,
                           uint _reservePrice,
                           uint _assetAmount,
                           uint _duration,
                           uint _strikePrice,
                           bool _isCall) public strikeSanityCheck(_asset, _isCall, _strikePrice) {
        require(_reservePrice > 0, "reserve price must be a positive value");
        require(_duration >= 3, "duration of the auction must be atleast 3 days");
        address assetAddress = stringsEqual(_asset, "WETH") ? maticWETH : maticWBTC;
        IERC20 erc;
        erc = IERC20(assetAddress);
        require(erc.balanceOf(msg.sender) >= _assetAmount, "not enough assets in user address");
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

    function placeBid(uint _amount, uint _auctionID) public notOwner(_auctionID) {
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

    function createOption(bytes calldata _ctx, bytes32 agreementId) private returns (bytes memory newCtx) {
        // we want to be able to have the CFA start when the writer creates the option.
        // reqire them to have a balance
        //create CFA between option owner and bidder
        // emit an event that our contract is created and start the flow with the sdk on the front end?
        newCtx = _ctx;
        address user = host.decodeCtx(_ctx).msgSender;
        (,int96 flowRate,,) = cfa.getFlowByID(superToken, agreementId);
        Auction memory auction = auctions[_auctionID];
        int256 price;
        require(!auction.optionCreated, "this option was already written!");
        require(msg.sender == auction.owner, "You are not the owner!");
        require(block.timestamp > auction.creationTime + auction.duration * 1 days, "Auction is not yet over, please wait until after to create option");
        require(auction.currentBidder != address(0) && auction.currentBid > 0, "There are no bidders for the option!");
        require(auction.currentBid >= auction.reservePrice, "Reserve price was not met.");
        address assetAddress = (stringsEqual(auction.asset, "WETH")) ? maticWETH : maticWBTC;
        if (assetAddress == maticWETH) {
            ethOracle.requestPriceData();
            price = ethOracle.price();
        } else {
            btcOracle.requestPriceData();
            price = btcOracle.price();

        }
        require(isCall ? price < auction.strikePrice : price > auction.strikePrice, "Strike price doesn't make sense with current prices");
        auction.optionCreated = true;
        uint optionId = optionContracts.length.add(1);
        address option = address(new Option(auction.asset,
                                    assetAddress,
                                    auction.assetAmount,
                                    auction.strikePrice,
                                    auction.isCall,
                                    auction.currentBid,
                                    auction.owner,
                                    auction.currentBidder,
                                    optionId,
                                    BTCoracle,
                                    ETHoracle));
        if (auction.isCall) {
            IERC20 erc;
            erc = IERC20(assetAddress);
            require(erc.balanceOf(msg.sender) >= auction.assetAmount, "not enough assets in user address");
            depositErc20(assetAddress, option, auction.assetAmount);
        } else {
            uint depositAmount = auction.assetAmount.mul(auction.strikePrice);
            depositErc20(maticDAI, option, depositAmount);
        }
        optionContracts.push(option);
    }

    /**
    * @dev Internal function to deposit ERC20
    *
    * */
    function depositErc20(
        address _tokenContract,
        address _optionContract,
        uint256 _amount
    )
        internal
    {
        IERC20 erc;
        erc = IERC20(_tokenContract);
        uint256 allowance = erc.allowance(msg.sender, address(this));
        require(allowance >= _amount, "Token allowance not enough");
        require(erc.transferFrom(msg.sender, _optionContract, _amount), "Transfer failed");
    }

    /**
    * @dev Internal function to compare strings
    *
    * */
    function stringsEqual(string memory _a, string memory _b) internal returns (bool) {
        return (keccak256(abi.encodePacked((_a))) == keccak256(abi.encodePacked((_b))));
    }

    function afterAgreementCreated(
        ISuperToken _superToken,
        address _agreementClass,
        bytes32 _agreementId,
        bytes calldata /*_agreementData*/,
        bytes calldata _cbdata,
        bytes calldata _ctx
    )
        external override
        onlyExpected(_superToken, _agreementClass)
        onlyHost
        returns (bytes memory)
    {
        return createOption(_ctx, _agreementId);
    }

    function _isAccepted(ISuperToken _superToken) private view returns (bool) {
        return address(_superToken) == address(fdaiX);
    }

    function _isCFAv1(address _agreementClass) private view returns (bool) {
        return ISuperAgreement(_agreementClass).agreementType()
            == keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1");
    }

    modifier onlyHost() {
        require(msg.sender == address(host), "RedirectAll: support only one host");
        _;
    }

    modifier onlyExpected(ISuperToken _superToken, address _agreementClass) {
        require(_isAccepted(_superToken) , "Option: not accepted token");
        require(_isCFAv1(_agreementClass), "Option: only CFAv1 supported");
        _;
    }


}