//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Exchange is ReentrancyGuard {
    IERC20 public euroToken; // address on sepolia : 0x08210F9170F89Ab7658F0B5E3fF39b0E03C594D4 - 6 decimals
    IERC20 public usdToken; // address on sepolia : 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238 - 6 decimals
    address owner;
    int256 exchangeRateEurToUsd;

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

    constructor(address _euroTokenAddress, address _usdTokenAddress) {
        euroToken = IERC20(_euroTokenAddress);
        usdToken = IERC20(_usdTokenAddress);
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
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

        emit ExchangeCompleted(msg.sender, amountInUsd, eurAmount, USD, EUR, exchangeRate);
        return eurAmount;
    }

    function sendMoney(uint256 amount, address to, uint8 sendCurrency, uint8 receiveCurrency)
        public
        nonReentrant
        returns (uint256)
    {
        if (amount == 0) revert InsufficientAmount();
        if (sendCurrency != EUR && sendCurrency != USD) revert InvalidCurrency();
        if (receiveCurrency != EUR && receiveCurrency != USD) revert InvalidCurrency();

        uint256 receiveAmount;
        int256 exchangeRate = getExchangeRate();
        if (exchangeRate <= 0) revert InvalidExchangeRate();

        if (sendCurrency == receiveCurrency) {
            if (sendCurrency == EUR) {
                bool success = euroToken.transferFrom(msg.sender, to, amount);
                if (!success) revert TransferFailed();
                receiveAmount = amount;
            } else if (sendCurrency == USD) {
                bool success = usdToken.transferFrom(msg.sender, to, amount);
                if (!success) revert TransferFailed();
                receiveAmount = amount;
            }
        } else {
            if (sendCurrency == EUR && receiveCurrency == USD) {
                receiveAmount = (amount * uint256(exchangeRate)) / 10 ** getDecimals();

                bool success = euroToken.transferFrom(msg.sender, address(this), amount);
                if (!success) revert TransferFailed();

                success = usdToken.transfer(to, receiveAmount);
                if (!success) revert TransferFailed();
            } else if (sendCurrency == USD && receiveCurrency == EUR) {
                receiveAmount = (amount * 10 ** getDecimals()) / uint256(exchangeRate);

                bool success = usdToken.transferFrom(msg.sender, address(this), amount);
                if (!success) revert TransferFailed();

                success = euroToken.transfer(to, receiveAmount);
                if (!success) revert TransferFailed();
            }
        }

        emit MoneySent(msg.sender, to, amount, receiveAmount, sendCurrency, receiveCurrency, exchangeRate);
        return receiveAmount;
    }

    // onlyOwner
    function addLiquidity(address token, uint256 amount) external onlyOwner {
        require(token == address(euroToken) || token == address(usdToken), "Invalid token");
        require(amount > 0, "Amount must be greater than 0");

        IERC20(token).transferFrom(msg.sender, address(this), amount);
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

    function setExchangeRate(int256 exchangeRate) public {
        exchangeRateEurToUsd = exchangeRate;
    }

    function getDecimals() public pure returns (uint8) {
        return decimals;
    }
}
