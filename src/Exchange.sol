//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {UsdERC20} from "./UsdERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Exchange is ReentrancyGuard, Ownable {
    IERC20 public euroToken;
    UsdERC20 public usdToken;
    int256 exchangeRateEurToUsd;

    // Chainlink price feed for ETH/USD
    AggregatorV3Interface public ethUsdPriceFeed;

    //CONSTANTS
    uint8 public constant EUR = 1;
    uint8 public constant USD = 2;
    uint8 public constant decimals = 8;

    //ERRORS
    error InsufficientAmount();
    error InvalidExchangeRate();
    error TransferFailed();
    error Unauthorized();
    error InvalidToken();
    error InvalidCurrency();
    error InsufficientEthProvided();
    error RefundFailed();
    error ChainlinkError();

    //EVENTS
    event ExchangeCompleted(
        address indexed user,
        uint256 sourceAmount,
        uint256 targetAmount,
        uint8 sourceCurrency,
        uint8 targetCurrency,
        int256 exchangeRate
    );
    event MoneySent(
        address indexed from,
        address indexed to,
        uint256 sendAmount,
        uint256 receiveAmount,
        uint8 sendCurrency,
        uint8 receiveCurrency,
        int256 exchangeRate
    );
    event LiquidityAdded(address token, uint256 amount);
    event UsdTokensMinted(address indexed to, uint256 amount, uint256 ethPaid);

    constructor(address _euroTokenAddress, address _usdTokenAddress, address _ethUsdPriceFeedAddress)
        Ownable(msg.sender)
    {
        euroToken = IERC20(_euroTokenAddress);
        usdToken = UsdERC20(_usdTokenAddress);
        ethUsdPriceFeed = AggregatorV3Interface(_ethUsdPriceFeedAddress);
    }

    function exchangeEurToUsd(uint256 amountInEur) public nonReentrant returns (uint256) {
        if (amountInEur == 0) revert InsufficientAmount();

        int256 exchangeRate = getExchangeRate();
        if (exchangeRate <= 0) revert InvalidExchangeRate();

        uint256 usdAmount = (amountInEur * uint256(exchangeRate)) / 10 ** getDecimals();

        bool success = euroToken.transferFrom(msg.sender, address(this), amountInEur);
        if (!success) revert TransferFailed();

        success = usdToken.transfer(msg.sender, usdAmount);
        if (!success) revert TransferFailed();

        emit ExchangeCompleted(msg.sender, amountInEur, usdAmount, EUR, USD, exchangeRate);
        return usdAmount;
    }

    function exchangeUsdToEur(uint256 amountInUsd) public nonReentrant returns (uint256) {
        if (amountInUsd == 0) revert InsufficientAmount();

        int256 exchangeRate = getExchangeRate();
        if (exchangeRate <= 0) revert InvalidExchangeRate();

        uint256 eurAmount = (amountInUsd * 10 ** getDecimals()) / uint256(exchangeRate);

        bool success = usdToken.transferFrom(msg.sender, address(this), amountInUsd);
        if (!success) revert TransferFailed();

        success = euroToken.transfer(msg.sender, eurAmount);
        if (!success) revert TransferFailed();

        emit ExchangeCompleted(msg.sender, amountInUsd, eurAmount, USD, EUR, 10 ** 8 * 10 ** 8 / exchangeRate);
        return eurAmount;
    }

    function sendMoney(uint256 amount, address to, uint8 sendCurrency, uint8 receiveCurrency)
        public
        nonReentrant
        returns (uint256 receiveAmount)
    {
        if (amount == 0) revert InsufficientAmount();
        if (sendCurrency != EUR && sendCurrency != USD) revert InvalidCurrency();
        if (receiveCurrency != EUR && receiveCurrency != USD) revert InvalidCurrency();

        int256 exchangeRate = getExchangeRate();
        if (exchangeRate <= 0) revert InvalidExchangeRate();

        if (sendCurrency == receiveCurrency) {
            if (sendCurrency == EUR) {
                bool success = euroToken.transferFrom(msg.sender, to, amount);
                if (!success) revert TransferFailed();
                receiveAmount = amount;
                emit MoneySent(msg.sender, to, amount, receiveAmount, sendCurrency, receiveCurrency, 100000000);
                return receiveAmount;
            } else if (sendCurrency == USD) {
                bool success = usdToken.transferFrom(msg.sender, to, amount);
                if (!success) revert TransferFailed();
                receiveAmount = amount;
                emit MoneySent(msg.sender, to, amount, receiveAmount, sendCurrency, receiveCurrency, 100000000);
                return receiveAmount;
            }
        } else {
            if (sendCurrency == EUR && receiveCurrency == USD) {
                receiveAmount = (amount * uint256(exchangeRate)) / 10 ** getDecimals();

                bool success = euroToken.transferFrom(msg.sender, address(this), amount);
                if (!success) revert TransferFailed();

                success = usdToken.transfer(to, receiveAmount);
                if (!success) revert TransferFailed();
                emit MoneySent(msg.sender, to, amount, receiveAmount, sendCurrency, receiveCurrency, exchangeRate);
                return receiveAmount;
            } else if (sendCurrency == USD && receiveCurrency == EUR) {
                receiveAmount = (amount * 10 ** getDecimals()) / uint256(exchangeRate);

                bool success = usdToken.transferFrom(msg.sender, address(this), amount);
                if (!success) revert TransferFailed();

                success = euroToken.transfer(to, receiveAmount);
                if (!success) revert TransferFailed();
                emit MoneySent(
                    msg.sender,
                    to,
                    amount,
                    receiveAmount,
                    sendCurrency,
                    receiveCurrency,
                    10 ** 8 * 10 ** 8 / exchangeRate
                );
                return receiveAmount;
            }
        }
    }

    // onlyOwner
    function addLiquidity(address token, uint256 amount) external {
        require(token == address(euroToken) || token == address(usdToken), "Invalid token");
        require(amount > 0, "Amount must be greater than 0");

        IERC20(token).transferFrom(msg.sender, address(this), amount);

        emit LiquidityAdded(token, amount);
    }

    function mintUsdTokens(uint256 usdAmount) external payable nonReentrant {
        if (usdAmount == 0) revert InsufficientAmount();
        (
            /* uint80 roundID */
            ,
            int256 price,
            /*uint startedAt*/
            ,
            /*uint timeStamp*/
            ,
            /*uint80 answeredInRound*/
        ) = ethUsdPriceFeed.latestRoundData();

        if (price <= 0) revert ChainlinkError();

        uint256 requiredEthAmount = (usdAmount * 1e20) / uint256(price);

        if (msg.value < requiredEthAmount) revert InsufficientEthProvided();

        usdToken.mint(msg.sender, usdAmount);

        uint256 excessEth = msg.value - requiredEthAmount;
        if (excessEth > 0) {
            (bool success,) = payable(msg.sender).call{value: excessEth}("");
            if (!success) revert RefundFailed();
        }

        emit UsdTokensMinted(msg.sender, usdAmount, requiredEthAmount);
    }

    function withdrawEth() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success,) = payable(msg.sender).call{value: balance}("");
            require(success, "ETH withdrawal failed");
        }
    }

    //getters
    function getEurcAddress() public view returns (address) {
        return address(euroToken);
    }

    function getUsdtAddress() public view returns (address) {
        return address(usdToken);
    }

    function getContractEurcBalance(address eurcToken) public view returns (uint256) {
        return IERC20(eurcToken).balanceOf(address(this));
    }

    function getContractUsdtBalance(address usdtToken) public view returns (uint256) {
        return IERC20(usdtToken).balanceOf(address(this));
    }

    function getExchangeRate() public view returns (int256) {
        return exchangeRateEurToUsd;
    }

    function setExchangeRate(int256 exchangeRate) public onlyOwner {
        exchangeRateEurToUsd = exchangeRate;
    }

    function getEthUsdPrice() public view returns (int256) {
        (
            /* uint80 roundID */
            ,
            int256 price,
            /*uint startedAt*/
            ,
            /*uint timeStamp*/
            ,
            /*uint80 answeredInRound*/
        ) = ethUsdPriceFeed.latestRoundData();

        return price;
    }

    function getDecimals() public pure returns (uint8) {
        return decimals;
    }

    function getRequiredEthForUsd(uint256 usdAmount) public view returns (uint256) {
        if (usdAmount == 0) return 0;

        (
            /* uint80 roundID */
            ,
            int256 price,
            /*uint startedAt*/
            ,
            /*uint timeStamp*/
            ,
            /*uint80 answeredInRound*/
        ) = ethUsdPriceFeed.latestRoundData();

        if (price <= 0) revert ChainlinkError();

        uint256 requiredEthAmount = (usdAmount * 1e20) / uint256(price);

        return requiredEthAmount;
    }

    receive() external payable {}
}

// Avantaje fata de PSD 2.
