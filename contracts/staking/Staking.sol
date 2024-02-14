// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {TimeMultisig} from "../generic/TimeMultisig.sol";
import {IStaking} from "./IStaking.sol";

contract Staking is IStaking, TimeMultisig, ReentrancyGuard {

    uint constant YEAR = 365 * 86_400;

    uint public YEAR_1_INTEREST = 50;
    uint public YEAR_2_INTEREST = 75;

    IERC20 private immutable visToken;
    mapping(address => StakingAccount) public stakings;
    mapping(uint => Bonus) public bonuses;

    uint public totalStakedAmount = 0;
    uint public lastDepositedBonusIndex = 0;

    struct StakingAccount {
        uint deposit;
        uint depositTimestamp;
        uint period;

        uint finalAmount;
        uint withdrawnInterest;
        uint lastWithdrawnBonusIndex;
    }

    struct Bonus {
        uint bonusAmount;
        uint totalDeposits;
        uint timestamp;
    }
    
    constructor(address visTokenAddress, address[] memory _owners) TimeMultisig(_owners, 3, 600) {
        visToken = IERC20(visTokenAddress);
    }

    function stake(address _owner, uint _amount, uint _period) public notPaused nonReentrant {
        require(_amount > 0, "Staking: Amount must be greater than 0");
        require(_period == 1 || _period == 2, "Staking: Invalid period");
        require(visToken.transferFrom(msg.sender, address(this), _amount), "Staking: Token transfer failed");

        if (stakings[_owner].period != 0) {
            uint eligibleBonusAndInterest = calculateEligibleInterest(_owner) + calculateEligibleBonus(_owner);

            StakingAccount storage acc = stakings[_owner];
            acc.depositTimestamp = block.timestamp;
            acc.deposit += _amount;

            require(acc.period == _period, "Staking: Period cannot be changed for this account");
            uint _interest = acc.period == 1 ? YEAR_1_INTEREST : YEAR_2_INTEREST;
            uint _finalAmount = acc.deposit * (1000 + (_interest * _period)) / 1000;
            acc.finalAmount = _finalAmount + eligibleBonusAndInterest;
            acc.lastWithdrawnBonusIndex = lastDepositedBonusIndex;
        } else {
            uint _interest = _period == 1 ? YEAR_1_INTEREST : YEAR_2_INTEREST;
            uint _finalAmount = _amount * (1000 + (_interest * _period)) / 1000;
            stakings[_owner] = StakingAccount({
                deposit: _amount,
                depositTimestamp: block.timestamp,
                period: _period,

                finalAmount: _finalAmount,
                withdrawnInterest: 0,
                lastWithdrawnBonusIndex: lastDepositedBonusIndex
            });
        }

        totalStakedAmount += _amount;

        emit NewStaking(_owner, _amount, _period);
    }

    function calculateEligibleBonus(address _owner) public view returns (uint eligibleBonus) {
        StakingAccount storage acc = stakings[_owner];
        require(acc.period != 0, "Staking: No account found");

        eligibleBonus = 0;
        for (uint i = acc.lastWithdrawnBonusIndex + 1; i <= lastDepositedBonusIndex; i++) {
            uint stakingEndsAt = acc.depositTimestamp + (YEAR * acc.period);
            if (bonuses[i].timestamp <= stakingEndsAt) {
                eligibleBonus += ((bonuses[i].bonusAmount * acc.deposit) / bonuses[i].totalDeposits);
            } else {
                break;
            }
        }
    }

    function calculateEligibleInterest(address _owner) public view returns (uint eligibleInterest) {
        StakingAccount storage acc = stakings[_owner];
        require(acc.period != 0, "Staking: No account found");

        uint totalFinalInterest = acc.finalAmount - acc.deposit;
        uint elapsedTime = block.timestamp - acc.depositTimestamp;

        // protection against accruing interest after staking has ended
        if (elapsedTime > YEAR * acc.period) {
            elapsedTime = YEAR * acc.period;
        }

        eligibleInterest = (totalFinalInterest * elapsedTime) / (YEAR * acc.period)  - acc.withdrawnInterest;
    }

    function claimInterest() public notPaused nonReentrant {
        StakingAccount storage acc = stakings[msg.sender];
        require(acc.period != 0, "Staking: No account found");

        uint eligibleBonus = calculateEligibleBonus(msg.sender);
        uint eligibleInterest = calculateEligibleInterest(msg.sender);
        uint eligibleAmount = eligibleBonus + eligibleInterest;

        acc.withdrawnInterest += eligibleInterest;
        acc.lastWithdrawnBonusIndex = lastDepositedBonusIndex;

        require(visToken.transfer(msg.sender, eligibleAmount), "Staking: Token transfer failed");

        emit InterestClaimed(msg.sender, eligibleAmount);
    }

    function withdrawStaking() public notPaused nonReentrant {
        StakingAccount storage acc = stakings[msg.sender];
        require(acc.period != 0, "Staking: No account found");
        require(block.timestamp >=  acc.depositTimestamp + (YEAR * acc.period),
            "Staking: Account not eligible for withdrawal yet");

        uint eligibleBonus = calculateEligibleBonus(msg.sender);
        uint eligibleInterest = calculateEligibleInterest(msg.sender);
        uint eligibleAmount = acc.deposit + eligibleBonus + eligibleInterest;

        require(visToken.transfer(msg.sender, eligibleAmount), "Staking: Token transfer failed");

        totalStakedAmount -= acc.deposit;

        delete stakings[msg.sender];

        emit StakingWithdrawn(msg.sender, eligibleAmount);
    }

    function setInterest(uint _interest_1y, uint _interest_2y) public onlyOwner enoughApprovals {
        YEAR_1_INTEREST = _interest_1y;
        YEAR_2_INTEREST = _interest_2y;
    }

    function bonusDeposit(uint _amount) public onlyOwner {
        require(_amount > 0, "Staking: Bonus deposit must be greater than 0");
        require(totalStakedAmount > 0, "Staking: Bonus deposit is not allowed when there are no staking accounts");
        require(visToken.transferFrom(msg.sender, address(this), _amount), "Staking: Token transfer failed");

        lastDepositedBonusIndex++;
        bonuses[lastDepositedBonusIndex] = Bonus({
            bonusAmount: _amount,
            totalDeposits: totalStakedAmount,
            timestamp: block.timestamp
        });

        emit BonusDeposit(_amount, totalStakedAmount);
    }

    function withdrawBalance(address _contractAddress, uint _amount, address _toAddress) public nonReentrant onlyOwner enoughApprovals {
        require(_contractAddress != address(0));
        IERC20 token = IERC20(_contractAddress);
        require(token.transfer(_toAddress, _amount), "Staking: Token withdrawal failed");
    }

}
