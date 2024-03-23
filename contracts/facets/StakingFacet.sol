// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// Importing required libraries
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibAppStorage} from "../libraries/LibAppStorage.sol";

// StakingFacet contract
contract StakingFacet {

    // Events
    event Stake(address _staker, uint256 _amount, uint256 _timeStaked);
    event Unstake(address _unstaker, uint256 _amount, uint256 _timeStaked);
    event Claim(address _claimer, uint256 _amount, uint256 _timeStaked);

    // Instance of LibAppStorage.Layout
    LibAppStorage.Layout internal l;

    // Custom error for insufficient balance
    error NoMoney(uint256 balance);

    // Function to stake a certain amount
    function stake(uint256 _amount) public {
        // Check if the amount is greater than 0 and the sender is not the zero address
        require(_amount > 0, "NotZero");
        require(msg.sender != address(0));
        //For future development, we can add a check to see if user already hit the max stake limit

        // Check if the sender has enough balance to stake
        uint256 balance = l.balances[msg.sender];
        require(balance >= _amount, "NotEnough");

        LibAppStorage.UserStake storage s = l.userDetails[msg.sender];
        if (s.amount > 0) {
            uint256 pending = (s.amount * l.accTokenPerShare / LibAppStorage.RATE_TOTAL_PRECISION) - s.rewardDebt;
            LibAppStorage._transferFrom(msg.sender, address(this), pending);
        }

        s.amount = s.amount + _amount;
        LibAppStorage._transferFrom(msg.sender, address(this), _amount);
        l.totalStaked += _amount;
        s.rewardDebt = s.amount * l.accTokenPerShare / LibAppStorage.RATE_TOTAL_PRECISION;

        // Emit the Stake event
        emit Stake(msg.sender, _amount, block.timestamp);
    }

    // Function to check the pending rewards for a staker
    function checkRewards(
    ) public returns (uint256 userPendingRewards) {
        LibAppStorage.UserStake storage s = l.userDetails[msg.sender];
        updatePool();

        userPendingRewards = (s.amount * l.accTokenPerShare / LibAppStorage.RATE_TOTAL_PRECISION) - s.rewardDebt;
    }

    // Function to calculate the reward per second
    function rewardPerSec () internal pure returns(uint256) {
        uint RPS = (LibAppStorage.ACC_REWARD_PRECISION * LibAppStorage.APY) / 31556952; // 1e18 * APY / seconds in a year
        return RPS;
    }

    function updatePool() internal {
        if (block.timestamp <= l.lastRewardTime) {
            return;
        }
        if (l.totalStaked == 0) {
            l.lastRewardTime = block.timestamp;
            return;
        }
        uint256 timeElapsed = block.timestamp - l.lastRewardTime;
        uint256 tokenReward = timeElapsed * rewardPerSec();
        l.accTokenPerShare = l.accTokenPerShare + ((tokenReward * LibAppStorage.RATE_TOTAL_PRECISION) / l.totalStaked);
        l.lastRewardTime = block.timestamp;
    }

    // Function to unstake a certain amount
    function unstake(uint256 _amount) public {
        // Get the staking details for the sender
        LibAppStorage.UserStake storage s = l.userDetails[msg.sender];

        // Check if the sender has enough staked amount to unstake
        if (s.amount < _amount) revert NoMoney(s.amount);
        updatePool();

        // Unstake the amount
        LibAppStorage._transferFrom(address(this), msg.sender, _amount);
        s.amount = s.amount - _amount;

        l.totalStaked = l.totalStaked - _amount;

        emit Unstake(msg.sender, _amount, block.timestamp);
    }

    function claimReward(address _from) public {
        LibAppStorage.UserStake storage s = l.userDetails[msg.sender];
        updatePool();

        uint256 pending = (s.amount * l.accTokenPerShare / LibAppStorage.RATE_TOTAL_PRECISION) - s.rewardDebt;
        require(pending > 0, "claimReward: No reward");
        bool success = IWOW(l.rewardToken).transferFrom(_from, msg.sender, pending);
        require(success, "Transfer failed");

        s.rewardDebt = s.amount * l.accTokenPerShare / LibAppStorage.RATE_TOTAL_PRECISION;
        emit Stake(msg.sender, pending, block.timestamp);
    }
}

// Interface for the reward token
interface IWOW {
    function mint(address _to, uint256 _amount) external;
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function totalSupply() external returns (uint256);
}

// address(this) is the address of the contract i.e. the diamond
// msg.sender is the address of the user i.e. the switchSigner used
