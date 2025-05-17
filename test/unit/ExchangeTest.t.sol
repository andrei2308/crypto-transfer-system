//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Exchange} from "../../src/Exchange.sol";
import {MockErc20} from "../mocks/MockERC20.sol";
import {UsdERC20} from "../../src/UsdERC20.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract ExchangeTest is Test {
    Exchange exchange;
    MockErc20 public eurc;
    UsdERC20 public usdt;
    MockV3Aggregator public ethUsdPriceFeed;

    address public owner = makeAddr("OWNER");
    address public user = makeAddr("USER");

    //constants
    uint8 public constant EURC_DECIMALS = 6;
    uint8 public constant USDT_DECIMALS = 6;
    uint8 public constant PRICE_FEED_DECIMALS = 8;
    int256 public constant INITIAL_PRICE = 1.1e8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    uint256 public constant INITIAL_LIQUIDITY_EURC = 1000 * 10 ** 6;
    uint256 public constant INITIAL_LIQUIDITY_USDT = 1000 * 10 ** 6;
    uint256 public constant USER_EURC_BALANCE = 100 * 10 ** 6;
    uint256 public constant USER_ETH_BALANCE = 10 ether;

    function setUp() external {
        ethUsdPriceFeed = new MockV3Aggregator(PRICE_FEED_DECIMALS, 20e8);

        vm.startPrank(owner);

        eurc = new MockErc20("Euro Token", "EUR", EURC_DECIMALS);

        UsdERC20ForTest modifiedUsdt = new UsdERC20ForTest("USD Token", "USD", USDT_DECIMALS);
        usdt = modifiedUsdt;

        eurc.mint(owner, INITIAL_LIQUIDITY_EURC);
        modifiedUsdt.mintForTest(owner, INITIAL_LIQUIDITY_USDT);

        exchange = new Exchange(address(eurc), address(modifiedUsdt), address(ethUsdPriceFeed));

        modifiedUsdt.setMinter(address(exchange));

        eurc.approve(address(exchange), INITIAL_LIQUIDITY_EURC);
        modifiedUsdt.approve(address(exchange), INITIAL_LIQUIDITY_USDT);

        exchange.addLiquidity(address(eurc), INITIAL_LIQUIDITY_EURC);
        exchange.addLiquidity(address(modifiedUsdt), INITIAL_LIQUIDITY_USDT);

        exchange.setExchangeRate(INITIAL_PRICE);

        eurc.mint(user, USER_EURC_BALANCE);

        vm.stopPrank();

        vm.deal(user, USER_ETH_BALANCE);
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

        assertEq(usdReceived, expectedUsdAmount);

        assertEq(initialEurcBalance - finalEurcBalance, eurAmount);
        assertEq(finalUsdtBalance - initialUsdtBalance, expectedUsdAmount);

        assertEq(finalContractEurcBalance - initialContractEurcBalance, eurAmount);
        assertEq(initialContractUsdBalance - finalContractUsdtBalance, usdReceived);
    }

    function testMintUsdTokens() public {
        (, int256 ethUsdPrice,,,) = ethUsdPriceFeed.latestRoundData();
        console.log("ETH/USD price:", uint256(ethUsdPrice) / 1e8, "USD");

        vm.startPrank(user);

        uint256 usdAmount = 5 * 10 ** USDT_DECIMALS;
        console.log("USD amount requested:", usdAmount / 1e6, "USD");

        uint256 ethToSend = 1 ether;
        console.log("ETH to send:", ethToSend / 1e18, "ETH");

        uint256 initialUsdtBalance = usdt.balanceOf(user);
        uint256 initialEthBalance = user.balance;

        exchange.mintUsdTokens{value: ethToSend}(usdAmount);

        uint256 finalUsdtBalance = usdt.balanceOf(user);
        uint256 finalEthBalance = user.balance;

        vm.stopPrank();

        console.log("Initial USD balance:", initialUsdtBalance / 1e6, "USD");
        console.log("Final USD balance:", finalUsdtBalance / 1e6, "USD");
        console.log("Initial ETH balance:", initialEthBalance / 1e18, "ETH");
        console.log("Final ETH balance:", finalEthBalance / 1e18, "ETH");

        assertEq(finalUsdtBalance - initialUsdtBalance, usdAmount, "USD tokens not minted correctly");

        assertTrue(initialEthBalance > finalEthBalance, "No ETH was spent");
    }
}

contract UsdERC20ForTest is UsdERC20 {
    constructor(string memory name, string memory symbol, uint8 decimalsValue) UsdERC20(name, symbol, decimalsValue) {}

    function mintForTest(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
