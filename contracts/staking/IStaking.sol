// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IStaking {

    event NewStaking(address indexed owner, uint amount, uint indexed period);
    event InterestClaimed(address indexed owner, uint amount);
    event StakingWithdrawn(address indexed owner, uint amount);
    event BonusDeposit(uint bonusAmount, uint totalDeposits);

    function stake(address _owner, uint _amount, uint _period) external;

    function calculateEligibleBonus(address _owner) external view returns (uint eligibleBonus);

    function calculateEligibleInterest(address _owner) external view returns (uint eligibleInterest);

    function claimInterest() external;

    function withdrawStaking() external;

    function setInterest(uint _period, uint _interest) external;

    function bonusDeposit(uint _amount) external;

}
