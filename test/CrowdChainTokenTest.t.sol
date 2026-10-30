// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.34;

import "../lib/forge-std/src/Test.sol";
import "../src/CrowdChain.sol";
import "../src/CrowdChainToken.sol";

contract CrowdChainTokenTest is Test {
    CrowdChainToken token;
    address owner = vm.addr(1);
    address randomUser = vm.addr(2);

    function setUp() public {
        token = new CrowdChainToken(owner);
    }

    function testProvideCrowdChainFailedDueToNotOwner() public {
        vm.startPrank(randomUser);

        vm.expectRevert(CrowdChainToken.Forbidden.selector);
        token.provideCrowdChain(address(new CrowdChain(owner, address(token), 5, 5 days)));

        vm.stopPrank();
    }

    function testProvideCrowdChainFailedDueToAddressNotValid() public {
        vm.startPrank(owner);

        vm.expectRevert(CrowdChainToken.AddressNotValid.selector);
        token.provideCrowdChain(address(0));

        vm.stopPrank();
    }

    function testProvideCrowdChainSuccess() public {
        vm.startPrank(owner);

        address crowdChain = address(new CrowdChain(owner, address(token), 5, 5 days));
        token.provideCrowdChain(crowdChain);
        assertEq(crowdChain, token.crowdChain());

        vm.stopPrank();
    }

    function testMintFailedDueToNotCrowdChain() public {
        vm.startPrank(randomUser);

        vm.expectRevert(CrowdChainToken.CrowdChainNotProvided.selector);
        token.mint(randomUser, 1);

        vm.stopPrank();
    }

    function testMintSuccess() public {
        vm.startPrank(owner);

        address crowdChainAddress = address(new CrowdChain(owner, address(token), 5, 5 days));
        token.provideCrowdChain(crowdChainAddress);

        vm.stopPrank();
        vm.startPrank(crowdChainAddress);

        token.mint(address(randomUser), 1);
        uint256 balance = IERC20(token).balanceOf(address(randomUser));
        assertEq(balance, 1);

        vm.stopPrank();
    }
}
