// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

interface IRebaseToken {
    function mint(
        address to,
        uint256 amount,
        uint256 userInterestRate
    ) external;
    function burn(address from, uint256 amount) external;
    function balanceOf(address user) external view returns (uint256);
    function getUserInterestRate(address user) external view returns (uint256);
    function getInterestRate() external view returns (uint256);
}
