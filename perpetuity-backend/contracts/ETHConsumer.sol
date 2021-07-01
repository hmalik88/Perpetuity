//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

import "@chainlink/contracts/src/v0.7/ChainlinkClient.sol";

contract ETHConsumer is ChainlinkClient {
    int256 public price;

    address private oracle;
    bytes32 private jobId;
    uint256 private fee;

    /**
     * Network: Mumbai
     * Chainlink - 0xc8D925525CA8759812d0c299B90247917d4d4b7C
     * Job Id - 93a2a3dbe96e4774ab8e277c5696bfac
     * Fee: 0.01 LINK
     */

    constructor() public {
        setChainlinkToken(0x70d1F773A9f81C852087B77F6Ae6d3032B02D2AB);
        oracle = 0xc8D925525CA8759812d0c299B90247917d4d4b7C;
        jobId = "93a2a3dbe96e4774ab8e277c5696bfac";
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
            "https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=USD"
        );
        request.add("path", "ethereum.usd");
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
