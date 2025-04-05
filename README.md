# 💱 Exchange Smart Contract

A Solidity-based smart contract for seamless EUR/USD token exchange with Chainlink price feed integration.

## 📝 Overview

This contract enables users to exchange between EUR and USD stablecoins with real-time exchange rates from Chainlink price feeds. It also supports cross-currency transfers, allowing users to send money in one currency that can be received in another.

## ⚙️ Features

- **Currency Exchange**: Convert between EUR and USD tokens based on real-time Chainlink price feeds
- **Direct Transfers**: Send funds to other users in the same currency
- **Cross-Currency Transfers**: Send EUR and recipient receives USD (or vice versa)
- **Liquidity Management**: Contract maintains liquidity pools for both currencies
- **Security**: Implements reentrancy protection and robust error handling

## 🔧 Technical Details

### Token Information

- **EUR Token**: ERC20 token with 6 decimals
  - Sepolia address: `0x08210F9170F89Ab7658F0B5E3fF39b0E03C594D4`
  
- **USD Token**: ERC20 token with 6 decimals
  - Sepolia address: `0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0`

### Price Feed

- **EUR/USD Chainlink Oracle**: 
  - Sepolia address: `0x1a81afB8146aeFfCFc5E50e8479e826E7D55b910`

### Dependencies

- **OpenZeppelin**:
  - `IERC20.sol`: For ERC20 token interface
  - `ReentrancyGuard.sol`: For protection against reentrancy attacks
- **Chainlink**:
  - `AggregatorV3Interface.sol`: For accessing price feed data

## 🛠️ Core Functions

### Exchange Functions

- `exchangeEurToUsd(uint256 amountInEur)`: Convert EUR to USD
- `exchangeUsdToEur(uint256 amountInUsd)`: Convert USD to EUR

### Transfer Functions

- `sendMoney(uint256 amount, address to, uint8 sendCurrency, uint8 receiveCurrency)`: Send money to another address with optional currency conversion

### Price Feed Functions

- `getLatestPrice()`: Get the current EUR/USD exchange rate
- `getDecimals()`: Get the number of decimals used in the price feed

### Liquidity Management

- `addLiquidity(address token, uint256 amount)`: Add liquidity to the contract (owner only)

## 📊 Events

- `ExchangeCompleted`: Emitted when a currency exchange is completed
- `MoneySent`: Emitted when funds are sent to another address

## 🔐 Error Handling

The contract implements custom errors for better gas efficiency and clarity:
- `InsufficientAmount`: Amount is zero or too low
- `InvalidExchangeRate`: Price feed returned invalid data
- `TransferFailed`: ERC20 token transfer failed
- `Unauthorized`: Caller is not authorized
- `InvalidToken`: Token address is not supported
- `InvalidCurrency`: Currency type is not supported

## 🚀 Getting Started

### Prerequisites

- Solidity ^0.8.18
- Chainlink contracts
- OpenZeppelin contracts

### Deployment

1. Deploy on Ethereum Sepolia testnet
2. Provide the following parameters:
   - Chainlink EUR/USD price feed address
   - EUR token address
   - USD token address

## 📜 License

SPDX-License-Identifier: MIT
