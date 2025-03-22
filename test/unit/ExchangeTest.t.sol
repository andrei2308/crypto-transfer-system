//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Exchange} from "../../src/Exchange.sol";
import {DeployExchange} from "../../script/DeployExchange.sol";
import {MockErc20} from "../mocks/MockERC20.sol";

contract ExchangeTest is Test {
    Exchange exchange;
    MockErc20 public eurc;
    MockErc20 public usdt;

    address public owner = makeAddr("OWNER");
    address public user = makeAddr("USER");

    //constants
    uint8 public constant EURC_DECIMALS = 6;
    uint8 public constant USDT_DECIMALS = 6;
    uint8 public constant PRICE_FEED_DECIMALS = 8;
    uint256 public constant INITIAL_PRICE = 1.1e8;
    uint256 public constant INITIAL_LIQUIDITY_EURC = 1000 * 10 ** 6; // 1000 EURC -> contract balance
    uint256 public constant INITIAL_LIQUIDITY_USDT = 1000 * 10 ** 6; // 1000 USDT -> contract balance
    uint256 public constant USER_EURC_BALANCE = 100 * 10 ** 6; // 100 eurc -> user balance
    uint256 public constant USER_USDT_BALANCE = 100 * 10 ** 6; // 100 usdt -> user balance

    function setUp() external {
        vm.prank(owner);
        DeployExchange deployExchange = new DeployExchange();
        exchange = deployExchange.run();
        eurc = MockErc20(exchange.getEurcAddress());
        usdt = MockErc20(exchange.getUsdtAddress());
        vm.deal(owner, INITIAL_LIQUIDITY_EURC);
        vm.deal(owner, INITIAL_LIQUIDITY_USDT);

        vm.startPrank(owner);

        eurc.mint(owner, INITIAL_LIQUIDITY_EURC);
        usdt.mint(owner, INITIAL_LIQUIDITY_USDT);

        eurc.approve(address(exchange), INITIAL_LIQUIDITY_EURC);
        usdt.approve(address(exchange), INITIAL_LIQUIDITY_USDT);

        exchange.addLiquidity(address(eurc), INITIAL_LIQUIDITY_EURC);
        exchange.addLiquidity(address(usdt), INITIAL_LIQUIDITY_USDT);

        vm.stopPrank();
        vm.deal(user, USER_EURC_BALANCE);
        vm.deal(user, USER_USDT_BALANCE);
        vm.startPrank(user);

        eurc.mint(user, USER_EURC_BALANCE);
        usdt.mint(user, USER_USDT_BALANCE);

        vm.stopPrank();
    }

    function testPriceFeedReturnsPrice() public view {
        assertEq(1.1e8, exchange.getLatestPrice());
    }

    function testPriceFeedReturnsDecimals() public view {
        assertEq(8, exchange.getDecimals());
    }

    function testExchangeEurToUsd() public {
        vm.startPrank(user);
        uint256 eurAmount = 10 * 10 ** EURC_DECIMALS;
        uint256 expectedUsdAmount = (eurAmount * uint256(INITIAL_PRICE)) / 10 ** PRICE_FEED_DECIMALS;

        eurc.approve(address(exchange), eurAmount);
        uint256 initialEurcBalance = eurc.balanceOf(user);
        uint256 initialUsdtBalance = usdt.balanceOf(user);
        uint256 initialContractEurcBalance = eurc.balanceOf(address(exchange));
        uint256 initialContractUsdBalance = usdt.balanceOf(address(exchange));

        uint256 usdReceived = exchange.exchangeEurToUsd(eurAmount);

        uint256 finalEurcBalance = eurc.balanceOf(user);
        uint256 finalUsdtBalance = usdt.balanceOf(user);
        uint256 finalContractEurcBalance = eurc.balanceOf(address(exchange));
        uint256 finalContractUsdtBalance = usdt.balanceOf(address(exchange));

        vm.stopPrank();

        // function verify
        assertEq(usdReceived, expectedUsdAmount);

        // user verify
        assertEq(initialEurcBalance - finalEurcBalance, eurAmount);
        assertEq(finalUsdtBalance - initialUsdtBalance, expectedUsdAmount);

        // contract verify
        assertEq(finalContractEurcBalance - initialContractEurcBalance, eurAmount);
        assertEq(initialContractUsdBalance - finalContractUsdtBalance, usdReceived);
    }

    //TODO: test pe sepolia
}
