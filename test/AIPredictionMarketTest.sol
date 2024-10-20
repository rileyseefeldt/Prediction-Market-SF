// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AIPredictionMarket} from "../src/AIPredictionMarket.sol";
import {MockERC20} from "./utils/MockERC20.sol";

contract AIPredictionMarketTest is Test {
    AIPredictionMarket predictionMarket;
    MockERC20 betToken;
    address feeRecipient = address(0xFEE);
    address alice = address(0x1);
    address bob = address(0x2);
    address carol = address(0x3);
    address dave = address(0x4);

    function setUp() public {
        // Deploy mock ERC20 token for testing
        betToken = new MockERC20("Bet Token", "BET", 18);

        // Mint tokens to test users
        betToken.mint(alice, 1000 ether);
        betToken.mint(bob, 1000 ether);
        betToken.mint(carol, 1000 ether);
        betToken.mint(dave, 1000 ether);

        // Deploy the prediction market contract
        predictionMarket = new AIPredictionMarket(
            IERC20(address(betToken)),
            feeRecipient
        );

        // Users approve the prediction market contract to spend their tokens
        vm.prank(alice);
        betToken.approve(address(predictionMarket), type(uint256).max);

        vm.prank(bob);
        betToken.approve(address(predictionMarket), type(uint256).max);

        vm.prank(carol);
        betToken.approve(address(predictionMarket), type(uint256).max);

        vm.prank(dave);
        betToken.approve(address(predictionMarket), type(uint256).max);
    }

    function testPlaceBet() public {
        // Alice bets on AI A
        vm.startPrank(alice);
        predictionMarket.placeBet(100 ether, true);
        vm.stopPrank();

        // Bob bets on AI B
        vm.startPrank(bob);
        predictionMarket.placeBet(200 ether, false);
        vm.stopPrank();

        // Check individual bets
        assertEq(predictionMarket.betsOnA(alice), 100 ether);
        assertEq(predictionMarket.betsOnB(bob), 200 ether);

        // Check total bets
        assertEq(predictionMarket.totalBetsOnA(), 100 ether);
        assertEq(predictionMarket.totalBetsOnB(), 200 ether);
    }

    function testWithdrawBet() public {
        // Alice places a bet and then withdraws it
        vm.startPrank(alice);
        predictionMarket.placeBet(100 ether, true);
        predictionMarket.withdrawBet(true);
        vm.stopPrank();

        // Check that her bet is withdrawn
        assertEq(predictionMarket.betsOnA(alice), 0);
        assertEq(predictionMarket.totalBetsOnA(), 0);
        assertEq(betToken.balanceOf(alice), 1000 ether); // She gets her tokens back
    }

    function testSettleMarketAndClaimReward() public {
        // Alice bets on AI A
        vm.startPrank(alice);
        predictionMarket.placeBet(100 ether, true);
        vm.stopPrank();

        // Bob bets on AI B
        vm.startPrank(bob);
        predictionMarket.placeBet(200 ether, false);
        vm.stopPrank();

        // Carol bets on AI A
        vm.startPrank(carol);
        predictionMarket.placeBet(300 ether, true);
        vm.stopPrank();

        // Total bets: AI A = 400 ether, AI B = 200 ether

        // Settle market: AI A wins
        predictionMarket.settleMarket(true);

        // Alice claims her reward
        vm.startPrank(alice);
        predictionMarket.claimReward();
        vm.stopPrank();

        // Carol claims her reward
        vm.startPrank(carol);
        predictionMarket.claimReward();
        vm.stopPrank();

        // Bob tries to claim reward but should fail
        vm.startPrank(bob);
        vm.expectRevert("No winning bet");
        predictionMarket.claimReward();
        vm.stopPrank();

        // Calculate expected rewards
        uint256 totalPool = 600 ether;
        uint256 feeAmount = (totalPool * predictionMarket.feePercent()) / predictionMarket.FEE_DIVISOR();
        uint256 totalPoolAfterFees = totalPool - feeAmount;

        uint256 aliceExpectedReward = (100 ether * totalPoolAfterFees) / 400 ether;
        uint256 carolExpectedReward = (300 ether * totalPoolAfterFees) / 400 ether;

        // Verify balances
        assertEq(betToken.balanceOf(alice), aliceExpectedReward + 900 ether); // Initial balance minus bet plus reward
        assertEq(betToken.balanceOf(carol), carolExpectedReward + 700 ether);

        // Verify fee recipient's balance
        assertEq(betToken.balanceOf(feeRecipient), feeAmount);
    }

    // Include other test functions as previously defined, ensuring they align with the updated contract.
}
