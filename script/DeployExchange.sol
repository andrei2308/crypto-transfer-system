//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Exchange} from "../src/Exchange.sol";
import {Configuration} from "./Configuration.sol";

contract DeployExchange is Script {
    function run() external returns (Exchange) {
        Configuration configuration = new Configuration();
        address eurUsdPriceFeed = configuration.activeChainConfiguration();
        vm.startBroadcast();
        Exchange exchange = new Exchange(eurUsdPriceFeed);
        vm.stopBroadcast();
        return exchange;
    }
}
