//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract UsdERC20 is ERC20, Ownable {
    uint8 private _decimals;
    address private _minter;

    constructor(string memory name, string memory symbol, uint8 decimalsValue)
        ERC20(name, symbol)
        Ownable(msg.sender)
    {
        _decimals = decimalsValue;
    }

    function setMinter(address minterAddress) external onlyOwner {
        _minter = minterAddress;
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == _minter, "Only minter can mint tokens");
        _mint(to, amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
}
