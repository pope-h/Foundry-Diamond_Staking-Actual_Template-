// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// Importing required libraries
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibAppStorage} from "../libraries/LibAppStorage.sol";

// StakingFacet contract
contract StakingFacet {
    // Event to be emitted when a stake is made
    event Stake(address _staker, uint256 _amount, uint256 _timeStaked);

    // Instance of LibAppStorage.Layout
    LibAppStorage.Layout internal l;

    // Custom error for insufficient balance
    error NoMoney(uint256 balance);

    // Function to stake a certain amount
    function stake(uint256 _amount) public {
        // Check if the amount is greater than 0 and the sender is not the zero address
        require(_amount > 0, "NotZero");
        require(msg.sender != address(0));

        // Check if the sender has enough balance to stake
        uint256 balance = l.balances[msg.sender];
        require(balance >= _amount, "NotEnough");

        // Transfer tokens from the sender to this contract
        LibAppStorage._transferFrom(msg.sender, address(this), _amount);
        
        // Update the staking details for the sender
        LibAppStorage.UserStake storage s = l.userDetails[msg.sender];
        s.stakedTime = block.timestamp;
        s.amount += _amount;
        uint256 IWOWTotalSupply = IWOW(l.rewardToken).totalSupply();
        s.allocatedPoints = (s.amount * IWOWTotalSupply / l.totalSupply); // l.totalSupply is totalAllocationPossible

        // Emit the Stake event
        emit Stake(msg.sender, _amount, block.timestamp);
    }

    // Function to check the pending rewards for a staker
    function checkRewards(
    ) public view returns (uint256 userPendingRewards) {
        // Get the staking details for the staker
        LibAppStorage.UserStake memory s = l.userDetails[msg.sender];

        // If the staker has staked before, calculate the pending rewards
        if (s.stakedTime > 0) {
            uint256 totalRewards = calculatePendingRewards();

            // Distribute the rewards evenly among all stakers
            userPendingRewards = totalRewards / (s.allocatedPoints * 2);
        }
    }

    // Function to calculate the reward per second
    function rewardPerSec () internal pure returns(uint256) {
        uint amount = LibAppStorage.ACC_REWARD_PRECISION * LibAppStorage.APY / 3154e7; // 1e18 * APY / seconds in a year
        return amount;
    }

    // Function to calculate the pending rewards for a user
   function calculatePendingRewards() internal view returns (uint256) {
        // Get the staking details for the user
        LibAppStorage.UserStake storage s = l.userDetails[msg.sender];
        uint256 timeElapsed = block.timestamp - (s.lastUnstakeTime > 0 ? s.lastUnstakeTime : s.stakedTime);
        return timeElapsed * rewardPerSec() * s.amount;
    }

    // Event to be emitted for debugging
    event y(uint);
    event Address(address _address, address _address2);

    // Function to unstake a certain amount
    function unstake(address _from, uint256 _amount) public {
        // Get the staking details for the sender
        LibAppStorage.UserStake storage s = l.userDetails[msg.sender];
        uint256 _reward = checkRewards();
        // require(s.amount >= _amount, "NoMoney");

        // Check if the sender has enough staked amount to unstake
        if (s.amount < _amount) revert NoMoney(s.amount);
        // Unstake the amount
        l.balances[address(this)] -= _amount;
        s.amount -= _amount;
        s.lastUnstakeTime = block.timestamp;
        LibAppStorage._transferFrom(address(this), msg.sender, _amount);

        // Check the rewards
        emit y(_reward);
        emit Address(_from, msg.sender);
        if (_reward > 0) {
            // Transfer the rewards to the sender
            // bool success = IWOW(l.rewardToken).transfer(address(this), reward);
            bool success = IWOW(l.rewardToken).transferFrom(_from, msg.sender, _reward);
            require(success, "Transfer failed");
        }
    }
}

// Interface for the reward token
interface IWOW {
    function mint(address _to, uint256 _amount) external;
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function totalSupply() external returns (uint256);
}