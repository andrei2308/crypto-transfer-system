//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";

// configuram dinamic pentru configuratie locala si chain de test - sepolia
contract Configuration is Script {
    ChainConfiguration public activeChainConfiguration;
    uint8 public constant decimals = 8;
    int256 public constant initialAnswer = 1.1e8; // 1 eur = 1.1 USD sa zicem pentru testing purposes

    struct ChainConfiguration {
        address priceFeed; // adresa contractului care returneaza EUR/USD
    }

    constructor() {
        if (block.chainid == 11155111) {
            activeChainConfiguration = getSepoliaConfiguration();
        } else {
            activeChainConfiguration = getAnvilConfiguration();
        }
    }

    function getSepoliaConfiguration() public pure returns (ChainConfiguration memory) {
        return ChainConfiguration(0x1a81afB8146aeFfCFc5E50e8479e826E7D55b910);
    }

    function getAnvilConfiguration() public returns (ChainConfiguration memory) {
        if (activeChainConfiguration.priceFeed != address(0)) {
            return activeChainConfiguration;
        }
        vm.startBroadcast();
        MockV3Aggregator mockV3Aggregator = new MockV3Aggregator(decimals, initialAnswer);
        vm.stopBroadcast();

        ChainConfiguration memory configuration = ChainConfiguration(address(mockV3Aggregator));
        return configuration;
    }
}
