//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "./Option.sol";
import "./BTCConsumer.sol";
import "./ETHConsumer.sol";
import "./AuctionFactory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import {
    ISuperfluid, 
    ISuperToken, 
    ISuperAgreement, 
    SuperAppDefinitions
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

import { IConstantFlowAgreementV1 } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";

import { SuperAppBase } from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperAppBase.sol";



contract OptionFactory is SuperAppBase {

    using SafeMath for uint256;

    address maticWETH = 0xE8F3118fDB41edcFEF7bF1DCa8009Fa8274aa070;
    address maticWBTC = 0x90ac599445B07c8aa0FC82248f51f6558136203D;
    address maticDAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    address private BTCoracle;
    address private ETHoracle;
    address private auctionFactoryAddress;
    BTCConsumer btcOracle;
    ETHConsumer ethOracle;

    ISuperfluid private host =
        ISuperfluid(0xEB796bdb90fFA0f28255275e16936D25d3418603);
    ISuperToken private superToken =
        ISuperToken(0x5D8B4C2554aeB7e86F387B4d6c00Ac33499Ed01f);
    IConstantFlowAgreementV1 private cfa =
        IConstantFlowAgreementV1(0x49e565Ed1bdc17F3d220f72DF0857C26FA83F873);
    AuctionFactory auctionFactory;

    
    address[] optionContracts;

    constructor(address _BTCoracle, address _ETHoracle, address _auctionFactory) {
        BTCoracle = _BTCoracle;
        ETHoracle = _ETHoracle;
        auctionFactoryAddress = _auctionFactory;
        btcOracle = BTCConsumer(BTCoracle);
        ethOracle = ETHConsumer(ETHoracle);
        auctionFactory = AuctionFactory(_auctionFactory);
        uint256 configWord = SuperAppDefinitions.APP_LEVEL_FINAL |
            SuperAppDefinitions.BEFORE_AGREEMENT_CREATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_UPDATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_TERMINATED_NOOP;

        host.registerApp(configWord);
    }

    function assetLockup(uint256 _amount, address _asset, address _sender) external {
        require(msg.sender == auctionFactoryAddress);
        IERC20 erc = IERC20(_asset);
        require(erc.allowance(_sender, address(this)) >= _amount);
        erc.transferFrom(_sender, address(this), _amount);
    }

    function createOption(bytes calldata _ctx, bytes32 _agreementId)
        private
        returns (bytes memory newCtx)
    {
        newCtx = _ctx;
        address user = host.decodeCtx(_ctx).msgSender;
        (uint256 _auctionId) = abi.decode(host.decodeCtx(_ctx).userData, (uint256));
        (, int96 flowRate, , ) = cfa.getFlowByID(superToken, _agreementId);
        AuctionFactory.Auction memory auction = auctionFactory.getAuctionInfo(_auctionId);
        int256 price;
        require(
            !auction.optionCreated, 
            "OPTION ALREADY EXISTS"
            );
        require(
            user == auction.currentBidder, 
            "CALLER IS NOT THE AUCTION WINNER"
            );
        require(
            block.timestamp > auction.creationTime + auction.duration * 1 days,
            "AUCTION IS NOT OVER"
            );
        require(
            auction.currentBidder != address(0) && auction.currentBid > 0,
            "AUCTION HAS NO BIDDERS"
            );
        require(uint256(flowRate) == auction.currentBid, "INCORRECT FLOW");
        address assetAddress = (stringsEqual(auction.asset, "WETH"))
            ? maticWETH
            : maticWBTC;
        if (assetAddress == maticWETH) {
            ethOracle.requestPriceData();
            price = ethOracle.price();
        } else {
            btcOracle.requestPriceData();
            price = btcOracle.price();
        }
        require(
            auction.isCall ? 
            uint256(price) < auction.strikePrice : 
            uint256(price) > auction.strikePrice,
            "STRIKE PRICE DOESN'T MAKE SENSE W/ CURRENT PRICES"
            );
        uint256 optionId = optionContracts.length.add(1);
        address option = address(
            new Option(
                auction.asset,
                assetAddress,
                auction.assetAmount,
                auction.strikePrice,
                auction.isCall,
                auction.currentBid,
                auction.owner,
                auction.currentBidder,
                optionId,
                BTCoracle,
                ETHoracle
            )
        );
        if (auction.isCall) {
            IERC20 erc = IERC20(assetAddress);
            require(
                erc.balanceOf(address(this)) >= auction.assetAmount,
                "INSUFFICIENT ASSETS"
                );
            depositErc20(assetAddress, option, auction.assetAmount);
        } else {
            depositErc20(
                maticDAI, 
                option, 
                auction.assetAmount.mul(auction.strikePrice)
            );
        }
        host.callAgreementWithContext(
            cfa,
            abi.encodeWithSelector(
                cfa.createFlow.selector,
                superToken,
                auction.owner,
                flowRate,
                new bytes(0) // placeholder
            ),
            "0x",
            _ctx
        );
        auctionFactory.completeAuction(_auctionId);
        optionContracts.push(option);
    }

    function stopFlowToOptionWriter(bytes calldata _ctx, bytes32)
        private
        returns (bytes memory newCtx)
    {
        (uint256 _auctionId, address optionAddress, bool isExecution) = abi.decode(host.decodeCtx(_ctx).userData, (uint256, address, bool));
        AuctionFactory.Auction memory auction = auctionFactory.getAuctionInfo(_auctionId);
        (newCtx, ) = host.callAgreementWithContext(
            cfa,
            abi.encodeWithSelector(
                cfa.deleteFlow.selector,
                superToken,
                address(this),
                auction.owner,
                new bytes(0) // placeholder
            ),
            "0x",
            _ctx
        );
        if (isExecution) Option(optionAddress).recoverAssets();
    }

    /**
     * @dev Internal function to deposit ERC20
     *
     * */
    function depositErc20(
        address _tokenContract,
        address _optionContract,
        uint256 _amount
    ) internal {
        IERC20 erc = IERC20(_tokenContract);
        require(
            erc.transfer(_optionContract, _amount),
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

    function afterAgreementCreated(
        ISuperToken _superToken,
        address _agreementClass,
        bytes32 _agreementId,
        bytes calldata, /*_agreementData*/
        bytes calldata,
        bytes calldata _ctx
    )
        external
        override
        onlyExpected(_superToken, _agreementClass)
        onlyHost
        returns (bytes memory)
    {
        return createOption(_ctx, _agreementId);
    }

    function afterAgreementTerminated(
        ISuperToken _superToken,
        address _agreementClass,
        bytes32 _agreementId,
        bytes calldata,
        bytes calldata, /*_cbdata*/
        bytes calldata _ctx
    ) external override onlyHost returns (bytes memory) {
        // According to the app basic law, we should never revert in a termination callback
        if (!_isAccepted(_superToken) || !_isCFAv1(_agreementClass))
            return _ctx;
        return stopFlowToOptionWriter(_ctx, _agreementId);
    }

    function _isAccepted(ISuperToken _superToken) private view returns (bool) {
        return address(_superToken) == address(superToken);
    }

    function _isCFAv1(address _agreementClass) private view returns (bool) {
        return
            ISuperAgreement(_agreementClass).agreementType() ==
            keccak256(
                "org.superfluid-finance.agreements.ConstantFlowAgreement.v1"
            );
    }

    modifier onlyHost() {
        require(
            msg.sender == address(host),
            "RedirectAll: support only one host"
        );
        _;
    }

    modifier onlyExpected(ISuperToken _superToken, address _agreementClass) {
        require(_isAccepted(_superToken), "Option: not accepted token");
        require(_isCFAv1(_agreementClass), "Option: only CFAv1 supported");
        _;
    }
}
