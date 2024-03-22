// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract WOWToken is ERC20 {
    // address DIAMOND;

    constructor() ERC20("WOW", "WOW") {
        // DIAMOND = _diamond;
    }

    function mint(address _to, uint256 _amount) public {
        // require(msg.sender == DIAMOND, "WOWToken: Only Diamond can mint");
        _mint(_to, _amount);
    }
}
