//SPDX-License-Identifier: MIT

import {Test, console} from "forge-std/Test.sol";
import {Exchange} from "../../src/Exchange.sol";
import {DeployExchange} from "../../script/DeployExchange.sol";

contract ExchangeTest is Test {
    Exchange exchange;

    function setUp() external {
        DeployExchange deployExchange = new DeployExchange();
        exchange = deployExchange.run();
    }

    function testPriceFeedReturnsPrice() public view {
        assertEq(1.1e8, exchange.getLatestPrice());
    }
}
