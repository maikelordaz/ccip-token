// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract Vault {
    IRebaseToken private immutable i_rebaseToken;

    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    error Vault__RedeemFailed();

    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    receive() external payable {}

    function deposit() external payable {
        // Use the msg.value to mint tokens in the RebaseToken contract
        i_rebaseToken.mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    function redeem(uint256 amount) external {
        i_rebaseToken.burn(msg.sender, amount);
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, Vault__RedeemFailed());
        emit Redeem(msg.sender, amount);
    }

    function getRebaseToken() external view returns (address) {
        return address(i_rebaseToken);
    }
}
