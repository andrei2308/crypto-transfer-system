//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Exchange} from "../src/Exchange.sol";
import {UsdERC20} from "../src/UsdERC20.sol";
import {Configuration} from "./Configuration.sol";

contract DeployExchangeSystem is Script {
    function run() external returns (Exchange, UsdERC20) {
        Configuration configuration = new Configuration();
        (address euroToken,) = configuration.activeChainConfiguration();

        address ethUsdPriceFeedAddress = 0x694AA1769357215DE4FAC081bf1f309aDC325306;

        vm.startBroadcast();

        UsdERC20 usdToken = new UsdERC20("USD Token", "USD", 6);

        Exchange exchange = new Exchange(euroToken, address(usdToken), ethUsdPriceFeedAddress);

        usdToken.setMinter(address(exchange));

        exchange.setExchangeRate(110000000);

        vm.stopBroadcast();

        return (exchange, usdToken);
    }
}
