//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {MockErc20} from "../test/mocks/MockERC20.sol";
// configuram dinamic pentru configuratie locala si chain de test - sepolia

contract Configuration is Script {
    ChainConfiguration public activeChainConfiguration;
    uint8 public constant decimals = 8;
    int256 public constant initialAnswer = 1.1e8; // 1 eur = 1.1 USD sa zicem pentru testing purposes

    struct ChainConfiguration {
        address priceFeed; // adresa contractului care returneaza EUR/USD
        address eurTokenAddress;
        address usdTokenAddress;
    }

    constructor() {
        if (block.chainid == 11155111) {
            activeChainConfiguration = getSepoliaConfiguration();
        } else {
            activeChainConfiguration = getAnvilConfiguration();
        }
    }

    function getSepoliaConfiguration() public pure returns (ChainConfiguration memory) {
        return ChainConfiguration(
            0x1a81afB8146aeFfCFc5E50e8479e826E7D55b910,
            0x08210F9170F89Ab7658F0B5E3fF39b0E03C594D4,
            0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0
        );
    }

    function getAnvilConfiguration() public returns (ChainConfiguration memory) {
        if (activeChainConfiguration.priceFeed != address(0)) {
            return activeChainConfiguration;
        }
        vm.startBroadcast();
        MockV3Aggregator mockV3Aggregator = new MockV3Aggregator(decimals, initialAnswer);
        MockErc20 mockEurcToken = new MockErc20("EURC", "EURC", decimals);
        MockErc20 mockUsdtToken = new MockErc20("USDT", "USDT", decimals);
        vm.stopBroadcast();

        ChainConfiguration memory configuration =
            ChainConfiguration(address(mockV3Aggregator), address(mockEurcToken), address(mockUsdtToken));
        return configuration;
    }
}
