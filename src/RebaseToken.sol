// SPDX-License-Identifier: MIT

/**
 * @title RebaseToken
 * @author Maikel Ordaz
 * @notice Cross-chain rebase token
 */

pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract RebaseToken is ERC20, Ownable, AccessControl {
    uint256 private constant PRECISION_FACTOR = 1e18;
    bytes32 private constant MINT_AND_BURN_ROLE =
        keccak256("MINT_AND_BURN_ROLE");

    uint256 private s_interestRate = (5 * PRECISION_FACTOR) / 1e8; // 10^8-8 == 1/10^8

    mapping(address users => uint256 interestRate) private s_userInterestRate;
    mapping(address user => uint256 lastUpdated)
        private s_userLastUpdatedTimestamp;

    event InteresRateSet(uint256 newInterestRate);

    error RebaseToken__InterestCanOnlyDecrease(
        uint256 oldInterestRate,
        uint256 newInterestRate
    );

    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender) {}

    function grantMintAndburnRole(address _user) external onlyOwner {
        // Grant the mint and burn role to the user
        _grantRole(MINT_AND_BURN_ROLE, _user);
    }

    /**
     * @notice Set the interest rate
     * @param newInterestRate The new interest rate
     * @dev The interest rate can only decrease
     */
    function setInterestRate(uint256 newInterestRate) external onlyOwner {
        // Set the new interest rate
        require(
            newInterestRate < s_interestRate,
            RebaseToken__InterestCanOnlyDecrease(
                s_interestRate,
                newInterestRate
            )
        );
        s_interestRate = newInterestRate;

        emit InteresRateSet(newInterestRate);
    }

    /**
     * @notice Get the principle balance of a user. This is the number of tokens that have
     * actually been minted to the user, not including any interest that has accumulated
     * since the last update.
     */
    function principleBalanceOf(address user) external view returns (uint256) {
        return super.balanceOf(user);
    }

    /**
     * @notice Mint tokens to a user when they deposit to the vault
     * @param to The user address
     * @param amount The amount of tokens to mint
     */
    function mint(
        address to,
        uint256 amount
    ) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(to);
        s_userInterestRate[to] = s_interestRate;
        _mint(to, amount);
    }

    /**
     * @notice Burn tokens from a user when they withdraw from the vault
     */
    function burn(
        address from,
        uint256 amount
    ) external onlyRole(MINT_AND_BURN_ROLE) {
        if (amount == type(uint256).max) {
            amount = balanceOf(from);
        }
        _mintAccruedInterest(from);
        _burn(from, amount);
    }

    /**
     * @notice Calculate the balance of a user including the interest that has accumulated since the last update
     *         principle balance + some interest
     * @param user The user address
     * @return The balance of the user including the interest
     */
    function balanceOf(address user) public view override returns (uint256) {
        // 1. Get the current principle balance of the user (the number of tokens that have actually been minted to the user)
        // 2. Multiply the principle balance by the interest rate that has accumulated since the balance was last updated
        return
            (super.balanceOf(user) *
                _calculateUserAccumulatedInterestSinceLastUpdate(user)) /
            PRECISION_FACTOR;
    }

    /**
     * @notice Transfer tokens from one user to another
     */
    function transfer(
        address _recipient,
        uint256 _amount
    ) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }
        return super.transfer(_recipient, _amount);
    }

    /**
     * @notice Transfer tokens from one user to another
     */
    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) public override returns (bool) {
        _mintAccruedInterest(_sender);
        _mintAccruedInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[_sender];
        }
        return super.transferFrom(_sender, _recipient, _amount);
    }

    /**
     * @notice Get the interest rate
     * @return The interest rate
     */
    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }

    /**
     * @notice Get the interest rate of a user
     * @param user The user address
     */
    function getUserInterestRate(address user) external view returns (uint256) {
        return s_userInterestRate[user];
    }

    /**
     * @notice Mint the accrued interest to the user since the last time they interacted with the contract
     */
    function _mintAccruedInterest(address _user) internal {
        // 1. Find current balance of rebase tokens that have been minted to the user -> principle balance
        uint256 previousPrincipleBalance = super.balanceOf(_user);
        // 2. Calculate their current balance including any interest -> balanceOf
        uint256 currentBalance = balanceOf(_user);
        // 3. Calculate number of token that need to be minted to the user -> 2. - 1.
        uint256 balanceIncrease = currentBalance - previousPrincipleBalance;
        // 4. Set the users last updated timestamp
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
        // 5. Call _mint to mint the tokens to the user
        _mint(_user, balanceIncrease);
    }

    /**
     * @notice Calculate the interest that has accumulated since the last update
     * @param _user The user address
     * @return _linearInterest The interest that has accumulated since the last update
     */
    function _calculateUserAccumulatedInterestSinceLastUpdate(
        address _user
    ) internal view returns (uint256 _linearInterest) {
        // Calculate the interest that has accumulated since the last update
        // This is linear growth in time
        // 1. Calculate the time since the last update
        // 2. Calculate the amount of linear growth
        // principal amount + (principal amount * interest rate for the user * time elapsed)
        // principale amount(1 + (interest rate * time elapsed))

        uint256 timeElapsed = block.timestamp -
            s_userLastUpdatedTimestamp[_user];
        _linearInterest =
            PRECISION_FACTOR +
            (s_userInterestRate[_user] * timeElapsed);
    }
}
