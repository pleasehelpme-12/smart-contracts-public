// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/0x540C605a35b943E12c928b1B5f2cb7df2C403409/token/ERC20/ERC20.sol";
import "@openzeppelin/0x540C605a35b943E12c928b1B5f2cb7df2C403409/token/ERC20/extensions/ERC20Burnable.sol";

contract Vis is ERC20, ERC20Burnable {
    
    constructor() ERC20("VIS Token", "POWER") {
        _mint(msg.sender, 1777777777 * 10 ** decimals());
    }

    function transfer(address to, uint256 value) public override returns (bool) {
        require(to != address(this));
        return super.transfer(to, value);
    }

}
