// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ERC.sol";

contract ALEO is ERC {
    constructor() ERC("ALEO", "Aleo", 10_000_000e18) {}
}