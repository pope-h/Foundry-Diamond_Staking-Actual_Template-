// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {SafeMath} from "../libraries/SafeMath.sol";

contract StakingFacet {
    event Stake(address _staker, uint256 _amount, uint256 _timeStaked);
    LibAppStorage.Layout internal l;
    using SafeMath for *;

    error NoMoney(uint256 balance);

    function stake(uint256 _amount) public {

        updatePool();

        require(_amount > 0, "NotZero");
        require(msg.sender != address(0));
        uint256 balance = l.balances[msg.sender];
        require(balance >= _amount, "NotEnough");
        //transfer out tokens to self
        LibAppStorage._transferFrom(msg.sender, address(this), _amount);
        //do staking math
        LibAppStorage.UserStake storage s = l.userDetails[msg.sender];
        s.stakedTime = block.timestamp;
        s.amount += _amount;
        emit Stake(msg.sender, _amount, block.timestamp);
    }

    function checkRewards(
        address _staker
    ) public view returns (uint256 userPendingRewards) {

        LibAppStorage.UserStake memory s = l.userDetails[_staker];
        if (s.stakedTime > 0) {
            uint256 duration = block.timestamp - s.stakedTime;
            uint256 rewardPerYear = s.amount * LibAppStorage.APY;
            uint256 reward = rewardPerYear / 3154e7;
            userPendingRewards = reward * duration;
        }
    }

    function rewardPerSec () internal pure returns(uint256) {
        uint amount = LibAppStorage.REWARD_PER_SEC.mul(LibAppStorage.REWARD_RATE).div(LibAppStorage.RATE_TOTAL_PRECISION).div(12);
        return amount;
    }

   function updatePool () internal {

        LibAppStorage.UserStake memory s = l.userDetails[msg.sender];

        // check that block.timeStamp is gt lastTimeStaked
        if(block.timestamp > l.lastStakedTime) {

            //geting rewardtoken totalSupply 
            uint256 reward_tot_supply = IWOW(l.rewardToken).totalSupply();

            if(reward_tot_supply > 0 && l.totalAllocatedPoints > 0){
                uint256 multiplier = block.timestamp.sub(l.lastStakedTime);

                uint256 calculateReward = multiplier.mul(rewardPerSec()).mul(s.allocatedPoints).div(l.totalAllocatedPoints);

                l.accRewardPerShare = l.accRewardPerShare.add((calculateReward.mul(LibAppStorage.ACC_REWARD_PRECISION)).div(reward_tot_supply));
            }

            l.lastStakedTime = block.timestamp;

        }
   }

    event y(uint);
    event Address(address _address, address _address2);

    function unstake(address _from, uint256 _amount) public {

        updatePool();

        LibAppStorage.UserStake storage s = l.userDetails[msg.sender];
        uint256 reward = checkRewards(msg.sender);
        // require(s.amount >= _amount, "NoMoney");

        if (s.amount < _amount) revert NoMoney(s.amount);
        //unstake
        l.balances[address(this)] -= _amount;
        s.amount -= _amount;
        s.stakedTime = s.amount > 0 ? block.timestamp : 0;
        LibAppStorage._transferFrom(address(this), msg.sender, _amount);
        //check rewards

        emit y(reward);
        emit Address(_from, msg.sender);
        if (reward > 0) {
            // bool success = IWOW(l.rewardToken).transfer(address(this), reward);
            bool success = IWOW(l.rewardToken).transferFrom(_from, msg.sender, reward);
            require(success, "Transfer failed");
        }
    }
}

interface IWOW {
    function mint(address _to, uint256 _amount) external;
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function totalSupply() external returns (uint256);
}