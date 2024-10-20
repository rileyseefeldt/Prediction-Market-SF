// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title AI Prediction Market Contract
/// @notice This contract allows users to bet on which AI will win in a competition.
contract AIPredictionMarket {
    // Mapping to keep track of users' bets on AI A and AI B
    mapping(address => uint256) public betsOnA;
    mapping(address => uint256) public betsOnB;

    // Total bets on each AI
    uint256 public totalBetsOnA;
    uint256 public totalBetsOnB;

    // Token used for bets
    IERC20 public betToken;

    // Address to receive the collected fees
    address public feeRecipient;

    // Market settlement status
    bool public marketSettled;
    bool public aiAWon;

    // Mapping to track if users have claimed their rewards
    mapping(address => bool) public rewardClaimed;

    // Fee percentage (0.5%)
    uint256 public constant FEE_DIVISOR = 1000; // Divisor for fee calculation
    uint256 public feePercent = 5; // 0.5% (feePercent / FEE_DIVISOR)

    // Events for logging activities
    event BetPlaced(address indexed user, bool betOnA, uint256 amount);
    event MarketSettled(bool aiAWon);
    event RewardClaimed(address indexed user, uint256 amount);

    // Flag to ensure the fee is transferred only once
    bool private feeTransferred;

    /// @notice Constructor to initialize the contract
    /// @param _betToken The ERC20 token used for bets
    /// @param _feeRecipient The address that will receive the fees
    constructor(
        IERC20 _betToken,
        address _feeRecipient
    ) {
        betToken = _betToken;
        feeRecipient = _feeRecipient;
    }

    /// @notice Allows users to place a bet on AI A or AI B
    /// @param amount The amount of tokens to bet
    /// @param betOnA True if betting on AI A, false if on AI B
    function placeBet(uint256 amount, bool betOnA) external {
        require(!marketSettled, "Market already settled");
        require(amount > 0, "Amount must be greater than zero");

        // Transfer betToken from user to contract
        require(betToken.transferFrom(msg.sender, address(this), amount), "Token transfer failed");

        if (betOnA) {
            betsOnA[msg.sender] += amount;
            totalBetsOnA += amount;
        } else {
            betsOnB[msg.sender] += amount;
            totalBetsOnB += amount;
        }

        emit BetPlaced(msg.sender, betOnA, amount);
    }

    /// @notice Settles the market by declaring the winning AI
    /// @param _aiAWon True if AI A won, false if AI B won
    function settleMarket(bool _aiAWon) external {
        require(!marketSettled, "Market already settled");
        // In production, this should be restricted or use an oracle
        aiAWon = _aiAWon;
        marketSettled = true;
        emit MarketSettled(aiAWon);
    }

    /// @notice Allows users to claim their rewards after the market is settled
    function claimReward() external {
        require(marketSettled, "Market not settled yet");
        require(!rewardClaimed[msg.sender], "Reward already claimed");

        uint256 userBet;
        uint256 userReward;
        uint256 totalWinningBets;
        uint256 totalLosingBets;

        if (aiAWon) {
            userBet = betsOnA[msg.sender];
            require(userBet > 0, "No winning bet");
            totalWinningBets = totalBetsOnA;
            totalLosingBets = totalBetsOnB;
        } else {
            userBet = betsOnB[msg.sender];
            require(userBet > 0, "No winning bet");
            totalWinningBets = totalBetsOnB;
            totalLosingBets = totalBetsOnA;
        }

        // Calculate fee
        uint256 totalPool = totalWinningBets + totalLosingBets;
        uint256 feeAmount = (totalPool * feePercent) / FEE_DIVISOR;
        uint256 totalPoolAfterFees = totalPool - feeAmount;

        // Calculate user's reward
        userReward = (userBet * totalPoolAfterFees) / totalWinningBets;

        // Mark reward as claimed
        rewardClaimed[msg.sender] = true;

        // Transfer reward to user
        require(betToken.transfer(msg.sender, userReward), "Token transfer failed");

        // Transfer fee to feeRecipient (only once)
        if (!feeTransferred && feeAmount > 0 && feeRecipient != address(0)) {
            feeTransferred = true;
            require(betToken.transfer(feeRecipient, feeAmount), "Fee transfer failed");
        }

        emit RewardClaimed(msg.sender, userReward);
    }

    /// @notice Returns the current odds for each AI based on total bets
    /// @return oddsA Odds for AI A (multiplied by 1000 for precision)
    /// @return oddsB Odds for AI B (multiplied by 1000 for precision)
    function getOdds() external view returns (uint256 oddsA, uint256 oddsB) {
        uint256 totalBets = totalBetsOnA + totalBetsOnB;
        if (totalBets == 0) {
            return (500, 500); // Default to 50% each
        } else {
            oddsA = (totalBetsOnA * 1000) / totalBets; // Odds in permille (‰)
            oddsB = (totalBetsOnB * 1000) / totalBets;
            return (oddsA, oddsB);
        }
    }

    /// @notice Allows users to withdraw their bets before the market is settled
    /// @param betOnA True if withdrawing a bet on AI A, false if on AI B
    function withdrawBet(bool betOnA) external {
        require(!marketSettled, "Market already settled");

        uint256 userBet;

        if (betOnA) {
            userBet = betsOnA[msg.sender];
            require(userBet > 0, "No bet to withdraw");

            betsOnA[msg.sender] = 0;
            totalBetsOnA -= userBet;
        } else {
            userBet = betsOnB[msg.sender];
            require(userBet > 0, "No bet to withdraw");

            betsOnB[msg.sender] = 0;
            totalBetsOnB -= userBet;
        }

        // Transfer tokens back to user
        require(betToken.transfer(msg.sender, userBet), "Token transfer failed");
    }
}
