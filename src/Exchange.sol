//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
//price feed chainlink eur/usd : 0x1a81afB8146aeFfCFc5E50e8479e826E7D55b910

contract Exchange {
    AggregatorV3Interface internal priceFeed;
    IERC20 public euroToken; // address on sepolia : 0x08210F9170F89Ab7658F0B5E3fF39b0E03C594D4 - 6 decimals
    IERC20 public usdToken; // address on sepolia : 0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0 - 6 decimals
    address owner;

    event ExchangeCompleted(address indexed user, uint256 euroAmount, uint256 usdAmount, int256 exchangeRate);

    constructor(address _priceFeedAddress, address _euroTokenAddress, address _usdTokenAddress) {
        priceFeed = AggregatorV3Interface(_priceFeedAddress);
        euroToken = IERC20(_euroTokenAddress);
        usdToken = IERC20(_usdTokenAddress);
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    function getLatestPrice() public view returns (int256) {
        (, int256 price,,,) = priceFeed.latestRoundData();
        return price;
    }

    function getDecimals() public view returns (uint8) {
        return priceFeed.decimals();
    }

    // TODO: gas eficient: fara require, definire erori, if(conditie){revert <nume_eroare>}, verificare gas efficiency metoda de transfer
    //posibil non-reentrant
    function exchangeEurToUsd(uint256 amountInEur) public returns (uint256) {
        require(amountInEur > 0, "Amount must be greater than 0");

        int256 exchangeRate = getLatestPrice();
        require(exchangeRate > 0, "Invalid exchange rate");

        //calculam valoare de usdt care se va obtine
        // pricefeed-ul returneaza rata de schimb cu 8 zecimale (e.g : 1.08 USD/EUR = 108000000)
        uint256 usdAmount = (amountInEur * uint256(exchangeRate)) / 10 ** getDecimals();

        // TODO: introducere fees, spread sau fixed rate, feature implementation

        // transferam euro catre contract
        require(euroToken.transferFrom(msg.sender, address(this), amountInEur), "EUR transfer failed");

        //transferam usd catre user
        require(usdToken.transfer(msg.sender, usdAmount), "USD transfer failed");

        // Emit event
        emit ExchangeCompleted(msg.sender, amountInEur, usdAmount, exchangeRate);

        return usdAmount;
    }

    // onlyOwner
    function addLiquidity(address token, uint256 amount) external {
        // !!! only owner ??
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
}
