// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract RebaseTokentTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;
    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndburnRole(address(vault));
        vm.stopPrank();
    }

    function addRewardsToVault(uint256 rewardAmount) public {
        (bool success, ) = payable(address(vault)).call{value: rewardAmount}(
            ""
        );
        require(success);
    }

    function testDepositLinear(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(user, amount);

        // 1.deposit
        vm.startPrank(user);
        vault.deposit{value: amount}();

        // 2. check rebase token balance
        uint256 startBalance = rebaseToken.balanceOf(user);
        console2.log("startBalance", startBalance);

        // 3. warp the time and check the balance again
        vm.warp(block.timestamp + 1 hours);

        uint256 middleBalance = rebaseToken.balanceOf(user);
        console2.log("middleBalance", middleBalance);

        // 4. warp the time and check the balance again
        vm.warp(block.timestamp + 1 hours);

        uint256 endBalance = rebaseToken.balanceOf(user);
        console2.log("endBalance", endBalance);

        vm.stopPrank();

        assertEq(startBalance, amount);
        assertGt(middleBalance, startBalance);
        assertGt(endBalance, middleBalance);
        assertApproxEqAbs(
            endBalance - middleBalance,
            middleBalance - startBalance,
            1
        );
    }

    function testRedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(user, amount);

        // 1.deposit
        vm.startPrank(user);
        vault.deposit{value: amount}();

        assertEq(rebaseToken.balanceOf(user), amount);

        // 2.redeem
        vault.redeem(type(uint256).max);

        vm.stopPrank();

        assertEq(rebaseToken.balanceOf(user), 0);
        assertEq(address(vault).balance, 0);
    }

    function testRedeemAfterTimePassed(
        uint256 depositmount,
        uint256 time
    ) public {
        time = bound(time, 1000, type(uint96).max);
        depositmount = bound(depositmount, 1e5, type(uint96).max);
        vm.deal(user, depositmount);

        // 1.deposit
        vm.prank(user);
        vault.deposit{value: depositmount}();

        // 2.warp the time and check the balance again
        vm.warp(block.timestamp + time);
        uint256 balanceAfterSomeTime = rebaseToken.balanceOf(user);

        vm.deal(owner, balanceAfterSomeTime - depositmount);

        vm.prank(owner);
        addRewardsToVault(balanceAfterSomeTime - depositmount);

        // 3.redeem
        vm.prank(user);
        vault.redeem(type(uint256).max);

        uint256 ethBalance = address(user).balance;

        assertEq(ethBalance, balanceAfterSomeTime);
        assertGt(ethBalance, depositmount);
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5 + 1e5, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5);

        vm.deal(user, amount);

        vm.prank(user);
        vault.deposit{value: amount}();

        address user2 = makeAddr("user2");
        uint256 userBalance = rebaseToken.balanceOf(user);
        uint256 user2Balance = rebaseToken.balanceOf(user2);

        assertEq(userBalance, amount);
        assertEq(user2Balance, 0);

        // owner reduce interes rate
        vm.prank(owner);
        rebaseToken.setInterestRate(4e10);

        vm.prank(user);
        rebaseToken.transfer(user2, amountToSend);
        uint256 userBalanceAfterTransfer = rebaseToken.balanceOf(user);
        uint256 user2BalanceAfterTransfer = rebaseToken.balanceOf(user2);

        assertEq(userBalanceAfterTransfer, userBalance - amountToSend);
        assertEq(user2BalanceAfterTransfer, amountToSend);

        //check interest rate of user has been inherited (5e10 not 4e10)
        assertEq(rebaseToken.getUserInterestRate(user), 5e10);
        assertEq(rebaseToken.getUserInterestRate(user2), 5e10);
    }

    function testCannotSetInteresRate() public {
        vm.prank(user);
        vm.expectPartialRevert(Ownable.OwnableUnauthorizedAccount.selector);
        rebaseToken.setInterestRate(4e10);
    }

    function testCannotCallMintAndBurn() public {
        vm.prank(user);
        vm.expectRevert();
        rebaseToken.mint(user, 1e5, rebaseToken.getInterestRate());

        vm.prank(user);
        vm.expectRevert();
        rebaseToken.burn(user, 1e5);
    }

    function testGetPrincipleAmount(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(user, amount);

        // 1.deposit
        vm.prank(user);
        vault.deposit{value: amount}();

        // 2.check principle amount
        assertEq(rebaseToken.principleBalanceOf(user), amount);

        vm.warp(block.timestamp + 1 hours);
        assertEq(rebaseToken.principleBalanceOf(user), amount);
    }

    function testGetRebaseTokenAddress() public view {
        assertEq(address(vault.getRebaseToken()), address(rebaseToken));
    }

    function testInterestRateCanOnlyDecrease(uint256 newInterestRate) public {
        uint256 initialInterestRate = rebaseToken.getInterestRate();

        newInterestRate = bound(
            newInterestRate,
            initialInterestRate,
            type(uint96).max
        );

        vm.prank(owner);
        vm.expectPartialRevert(
            RebaseToken.RebaseToken__InterestCanOnlyDecrease.selector
        );
        rebaseToken.setInterestRate(newInterestRate);

        assertEq(rebaseToken.getInterestRate(), initialInterestRate);
    }

    function testCannotGrantMintAndBurnRole() public {
        vm.prank(user);
        vm.expectPartialRevert(Ownable.OwnableUnauthorizedAccount.selector);
        rebaseToken.grantMintAndburnRole(user);
    }
}
