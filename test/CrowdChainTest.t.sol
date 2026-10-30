// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.34;

import "../lib/forge-std/src/Test.sol";
import "../src/CrowdChain.sol";
import "../src/CrowdChainToken.sol";

contract CrowdChainTest is Test {
    CrowdChain crowdChain;
    CrowdChainToken token;

    // Constants
    address owner = vm.addr(1);
    address randomUser = vm.addr(2);
    uint256 constant duration = 7 days;
    uint256 constant moneyTarget = 20 ether;

    function setUp() public {
        token = new CrowdChainToken(owner);
        crowdChain = new CrowdChain(owner, address(token), moneyTarget, duration);

        vm.startPrank(owner);
        token.provideCrowdChain(address(crowdChain));
        vm.stopPrank();
    }

    function testCrowdChainCorrectlyDeployed() public view {
        assertNotEq(address(crowdChain), address(0));
    }

    // Constructor

    function testConstructorFailedDueToOwnerNotValid() public {
        vm.expectRevert();
        crowdChain = new CrowdChain(address(0), address(token), moneyTarget, duration);
    }

    function testConstructorFailedDueToTargetMinimumNotReached() public {
        vm.expectRevert();
        crowdChain = new CrowdChain(owner, address(token), 0, duration);
    }

    function testConstructorFailedDueToDurationMinimumNotReached() public {
        vm.expectRevert();
        crowdChain = new CrowdChain(owner, address(token), moneyTarget, 0);
    }

    function testConstructorFailedDueToTokenNotValid() public {
        vm.expectRevert();
        crowdChain = new CrowdChain(owner, address(0), moneyTarget, duration);
    }

    // Contribute

    function testContribute() public {
        vm.startPrank(randomUser);

        uint256 amount = 2 ether;
        vm.deal(randomUser, amount);

        crowdChain.contribute{value: 2 ether}();

        vm.stopPrank();
        assertEq(address(crowdChain).balance, amount);
    }

    function testContributeFailedDueToNoMoneyReceived() public {
        vm.expectRevert(CrowdChain.NoMoneyReceived.selector);
        crowdChain.contribute{value: 0 ether}();
    }

    function testContributeFailedDueToContributionOverTarget() public {
        vm.startPrank(randomUser);
        vm.deal(randomUser, moneyTarget + 1);

        vm.expectRevert(CrowdChain.ContributeOverTarget.selector);
        crowdChain.contribute{value: moneyTarget + 1}();

        vm.stopPrank();
    }

    // Extract funds

    function testExtractFundsFailedDueToNotOwner() public {
        vm.expectRevert(CrowdChain.NotOwner.selector);
        crowdChain.extractFunds(1 ether);
    }

    function testExtractFundsFailedDueToStillActive() public {
        vm.startPrank(owner);

        vm.expectRevert(CrowdChain.CrowdFundingStillActive.selector);
        crowdChain.extractFunds(1 ether);

        vm.stopPrank();
    }

    function testExtractFundsFailedDueToCompletedUnsuccessfully() public {
        vm.startPrank(owner);

        vm.warp(block.timestamp + duration + 1);

        vm.expectRevert(CrowdChain.CroudFundingNotCompleted.selector);
        crowdChain.extractFunds(1 ether);

        vm.stopPrank();
    }

    function testExtractFundsFailedDueToPaymentFailed() public {
        vm.startPrank(owner);

        vm.deal(owner, moneyTarget);
        crowdChain.contribute{value: moneyTarget}();
        vm.deal(address(crowdChain), 0);

        vm.expectRevert(CrowdChain.PaymentFailed.selector);
        crowdChain.extractFunds(1 ether);

        vm.stopPrank();
    }

    function testExtractFundsSuccess() public {
        vm.startPrank(owner);

        vm.deal(owner, moneyTarget);
        crowdChain.contribute{value: moneyTarget}();

        uint256 amountToRetire = 1 ether;
        uint256 previousBalance = crowdChain.balanceRetiredByOwner();
        crowdChain.extractFunds(amountToRetire);
        uint256 afterBalance = crowdChain.balanceRetiredByOwner();

        assertEq(afterBalance - previousBalance, amountToRetire);

        vm.stopPrank();
    }

    // Recover funds

    function testRecoverFundsFailedDueToStillActive() public {
        vm.expectRevert(CrowdChain.CrowdFundingStillActive.selector);
        crowdChain.recoverFunds();
    }

    function testRecoverFundsFailedDueToCompletedWithSuccess() public {
        vm.startPrank(randomUser);
        vm.deal(randomUser, moneyTarget);

        crowdChain.contribute{value: moneyTarget}();

        vm.expectRevert(CrowdChain.CrowdFundingCompleted.selector);
        crowdChain.recoverFunds();

        vm.stopPrank();
    }

    function testRecoverFundsFailedDueToNoMoneyAvailable() public {
        vm.startPrank(randomUser);
        vm.warp(block.timestamp + duration + 1);

        vm.expectRevert(CrowdChain.NotAvailableAmount.selector);
        crowdChain.recoverFunds();

        vm.stopPrank();
    }

    function testRecoverFundsFailedDueToPaymentFailed() public {
        vm.startPrank(randomUser);
        uint256 amount = 1 ether;
        vm.deal(randomUser, amount);
        crowdChain.contribute{value: amount}();
        vm.warp(block.timestamp + duration + 1);

        vm.deal(address(crowdChain), 0);
        vm.expectRevert(CrowdChain.PaymentFailed.selector);
        crowdChain.recoverFunds();

        vm.stopPrank();
    }

    function testRecoverFundsSuccess() public {
        vm.startPrank(randomUser);
        uint256 amount = 1 ether;
        vm.deal(randomUser, amount);
        crowdChain.contribute{value: amount}();
        vm.warp(block.timestamp + duration + 1);

        uint256 balanceBefore = crowdChain.userBalance(randomUser);
        crowdChain.recoverFunds();
        uint256 balanceAfter = crowdChain.userBalance(randomUser);
        assertEq(balanceBefore - balanceAfter, amount);

        vm.stopPrank();
    }

    // completedWithSuccess

    function testCompletedWithSuccess() public {
        assertEq(crowdChain.completedWithSuccess(), false);

        // Complete crowdfunding successfully
        vm.startPrank(randomUser);
        vm.deal(randomUser, moneyTarget);
        crowdChain.contribute{value: moneyTarget}();
        assertEq(crowdChain.completedWithSuccess(), true);

        vm.stopPrank();
    }

    // moneyToCompleteTarget

    function testMoneyToCompleteTarget() public {
        vm.startPrank(randomUser);
        uint256 amount = 1 ether;
        vm.deal(randomUser, amount);
        crowdChain.contribute{value: amount}();
        assertEq(crowdChain.moneyToCompleteTarget(), moneyTarget - amount);
    }

    // reclaimRewards

    function testReclaimRewardsFailedDueToCrowdFundingStillActive() public {
        vm.expectRevert(CrowdChain.CrowdFundingStillActive.selector);
        crowdChain.reclaimRewards();
    }

    function testReclaimRewardsFailedDueToNotCompletedSuccessfully() public {
        vm.warp(block.timestamp + duration + 1);
        vm.expectRevert(CrowdChain.CroudFundingNotCompleted.selector);
        crowdChain.reclaimRewards();
    }

    function testReclaimRewardsFailedDueToNoContributionDone() public {
        vm.startPrank(randomUser);

        vm.deal(randomUser, moneyTarget);
        crowdChain.contribute{value: moneyTarget}();

        vm.stopPrank();
        vm.startPrank(owner);

        vm.expectRevert(CrowdChain.NoRewardAvailable.selector);
        crowdChain.reclaimRewards();

        vm.stopPrank();
    }

    function testReclaimRewardsFailedDueToAlreadyClaimed() public {
        vm.startPrank(randomUser);

        vm.deal(randomUser, moneyTarget);
        crowdChain.contribute{value: moneyTarget}();

        // Provide tokens to crowdChain
        vm.stopPrank();
        vm.startPrank(address(crowdChain));
        uint256 tokenAmount = moneyTarget * crowdChain.tokenConversion();
        IERC20(token).approve(randomUser, tokenAmount);
        vm.stopPrank();
        vm.startPrank(randomUser);

        crowdChain.reclaimRewards();
        vm.expectRevert(CrowdChain.AlreadyReclaimedRewards.selector);
        crowdChain.reclaimRewards();

        vm.stopPrank();
    }

    function testReclaimRewardsSuccess() public {
        vm.startPrank(randomUser);

        vm.deal(randomUser, moneyTarget);
        crowdChain.contribute{value: moneyTarget}();

        // Provide tokens to crowdChain
        vm.stopPrank();
        vm.startPrank(address(crowdChain));

        uint256 tokenAmount = moneyTarget * crowdChain.tokenConversion();
        IERC20(token).approve(address(crowdChain), tokenAmount);

        vm.stopPrank();
        vm.startPrank(randomUser);

        uint256 previousBalance = IERC20(token).balanceOf(randomUser);
        crowdChain.reclaimRewards();
        uint256 afterBalance = IERC20(token).balanceOf(randomUser);

        assertEq(afterBalance - previousBalance, moneyTarget * crowdChain.tokenConversion());

        vm.stopPrank();
    }
}
