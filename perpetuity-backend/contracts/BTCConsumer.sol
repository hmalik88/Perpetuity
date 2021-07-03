//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

import "@chainlink/contracts/src/v0.7/ChainlinkClient.sol";

contract BTCConsumer is ChainlinkClient {
    using Chainlink for Chainlink.Request;

    int256 public price;

    address private oracle;
    bytes32 private jobId;
    uint256 private fee;

    /**
     * Network: Mumbai
     * Chainlink - 0xc8D925525CA8759812d0c299B90247917d4d4b7C
     * Job Id - cb031a72c98e4acea606347ba061a6d8
     * Fee: 0.01 LINK
     */

    constructor() {
        setChainlinkToken(0x70d1F773A9f81C852087B77F6Ae6d3032B02D2AB);
        oracle = 0xc8D925525CA8759812d0c299B90247917d4d4b7C;
        jobId = "cb031a72c98e4acea606347ba061a6d8";
        fee = 0.01 * 10**18; // 0.01 LINK
    }

    function requestPriceData() public returns (bytes32 requestId) {
        Chainlink.Request memory request = buildChainlinkRequest(
            jobId,
            address(this),
            this.fulfill.selector
        );
        request.add(
            "get",
            "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=USD"
        );
        request.add("path", "bitcoin.usd");
        request.addInt("times", 100);
        return sendChainlinkRequestTo(oracle, request, fee);
    }

    function fulfill(bytes32 _requestId, int256 _price)
        public
        recordChainlinkFulfillment(_requestId)
    {
        price = _price;
    }
}
