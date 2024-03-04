// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TimeMultisig} from "../generic/TimeMultisig.sol";
import {IStaking} from "./IStaking.sol";

contract Staking is IStaking, TimeMultisig {

    uint constant YEAR = 365 * 86_400;

    uint public YEAR_1_INTEREST = 50; // 10 = 1%
    uint public YEAR_2_INTEREST = 75; // 10 = 1%

    IERC20 private immutable visToken;
    mapping(address => StakingAccount) public stakings;
    mapping(uint => Bonus) public bonuses;

    uint public totalStakedAmount = 0;
    uint public totalRequiredOutputAmount = 0;
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

    /**
     * @dev Stake VIS tokens for a specified period.
     * @param _owner The owner's address for whom staking is initiated.
     * @param _amount The amount of VIS tokens to stake.
     * @param _period The staking period: 1 for 1-year, 2 for 2-year.
     */
    function stake(address _owner, uint _amount, uint _period) public notPaused {
        require(_amount > 0, "Staking: Amount must be greater than 0");
        require(_period == 1 || _period == 2, "Staking: Invalid period");
        require(visToken.transferFrom(msg.sender, address(this), _amount), "Staking: Token transfer failed");

        if (stakings[_owner].period != 0) {
            uint eligibleInterest = calculateEligibleInterest(_owner);
            uint eligibleBonus = calculateEligibleBonus(_owner);

            StakingAccount storage acc = stakings[_owner];
            acc.depositTimestamp = block.timestamp;
            acc.deposit += _amount;

            require(acc.period == _period, "Staking: Period cannot be changed for this account");
            uint _interest = acc.period == 1 ? YEAR_1_INTEREST : YEAR_2_INTEREST;
            uint _finalAmount = acc.deposit * (1000 + (_interest * _period)) / 1000;

            totalRequiredOutputAmount -= acc.finalAmount;
            totalRequiredOutputAmount += _finalAmount + eligibleInterest;

            acc.finalAmount = _finalAmount + eligibleBonus + eligibleInterest;
            acc.lastWithdrawnBonusIndex = lastDepositedBonusIndex;
        } else {
            uint _interest = _period == 1 ? YEAR_1_INTEREST : YEAR_2_INTEREST;
            uint _finalAmount = _amount * (1000 + (_interest * _period)) / 1000;

            totalRequiredOutputAmount += _finalAmount;

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

    /**
     * @dev Calculate the eligible bonus for the given owner.
     * @param _owner The owner's address for whom the bonus is calculated.
     * @return eligibleBonus The eligible bonus amount.
     */
    function calculateEligibleBonus(address _owner) public view returns (uint eligibleBonus) {
        StakingAccount storage acc = stakings[_owner];
        require(acc.period != 0, "Staking: No account found");

        eligibleBonus = 0;
        uint stakingEndsAt = acc.depositTimestamp + (YEAR * acc.period);
        uint256 _lastDepositedBonusIndex = lastDepositedBonusIndex;
        for (uint i = acc.lastWithdrawnBonusIndex + 1; i <= _lastDepositedBonusIndex; i++) {
            if (bonuses[i].timestamp <= stakingEndsAt) {
                eligibleBonus += ((bonuses[i].bonusAmount * acc.deposit) / bonuses[i].totalDeposits);
            } else {
                break;
            }
        }
    }

    /**
     * @dev Calculate the eligible interest for the given owner.
     * @param _owner The owner's address for whom the interest is calculated.
     * @return eligibleInterest The eligible interest amount.
     */
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

    /**
     * @dev Claim the interest and bonuses for the calling address.
     */
    function claimInterest() public notPaused {
        StakingAccount storage acc = stakings[msg.sender];
        require(acc.period != 0, "Staking: No account found");
        require(visToken.balanceOf(address(this)) >= totalRequiredOutputAmount, "Staking: Contract must be properly funded");

        uint eligibleBonus = calculateEligibleBonus(msg.sender);
        uint eligibleInterest = calculateEligibleInterest(msg.sender);
        uint eligibleAmount = eligibleBonus + eligibleInterest;

        acc.withdrawnInterest += eligibleInterest;
        acc.lastWithdrawnBonusIndex = lastDepositedBonusIndex;

        totalRequiredOutputAmount -= eligibleAmount;
        require(visToken.transfer(msg.sender, eligibleAmount), "Staking: Token transfer failed");

        emit InterestClaimed(msg.sender, eligibleAmount);
    }

    /**
     * @dev Withdraw staked amount along with interest and bonuses for the calling address.
     */
    function withdrawStaking() public notPaused {
        StakingAccount storage acc = stakings[msg.sender];
        require(acc.period != 0, "Staking: No account found");
        require(block.timestamp >=  acc.depositTimestamp + (YEAR * acc.period),
            "Staking: Account not eligible for withdrawal yet");
        require(visToken.balanceOf(address(this)) >= totalRequiredOutputAmount, "Staking: Contract must be properly funded");

        uint eligibleBonus = calculateEligibleBonus(msg.sender);
        uint eligibleInterest = calculateEligibleInterest(msg.sender);
        uint eligibleAmount = acc.deposit + eligibleBonus + eligibleInterest;

        totalRequiredOutputAmount -= eligibleAmount;
        require(visToken.transfer(msg.sender, eligibleAmount), "Staking: Token transfer failed");

        totalStakedAmount -= acc.deposit;

        delete stakings[msg.sender];

        emit StakingWithdrawn(msg.sender, eligibleAmount);
    }

    /**
     * @dev Set the interest rates for 1-year and 2-year staking periods.
     * @param _interest_1y The interest rate for 1-year staking period.
     * @param _interest_2y The interest rate for 2-year staking period.
     */
    function setInterest(uint _interest_1y, uint _interest_2y) public onlyOwner
            enoughApprovals(abi.encodePacked("SET_INTEREST", _interest_1y, _interest_2y)) {
        YEAR_1_INTEREST = _interest_1y;
        YEAR_2_INTEREST = _interest_2y;
    }

    /**
     * @dev Deposit bonus amount into the staking contract.
     * @param _amount The amount of bonus tokens to deposit.
     */
    function bonusDeposit(uint _amount) public onlyOwner {
        require(_amount > 0, "Staking: Bonus deposit must be greater than 0");
        require(totalStakedAmount > 0, "Staking: Bonus deposit is not allowed when there are no staking accounts");
        require(visToken.transferFrom(msg.sender, address(this), _amount), "Staking: Token transfer failed");

        totalRequiredOutputAmount += _amount;
        lastDepositedBonusIndex++;
        bonuses[lastDepositedBonusIndex] = Bonus({
            bonusAmount: _amount,
            totalDeposits: totalStakedAmount,
            timestamp: block.timestamp
        });

        emit BonusDeposit(_amount, totalStakedAmount);
    }

    /**
     * @dev Withdraw token balance from the contract to a specified address.
     * @param _contractAddress The address of the token contract.
     * @param _amount The amount of tokens to withdraw.
     * @param _toAddress The address to receive the tokens.
     */
    function withdrawBalance(address _contractAddress, uint _amount, address _toAddress) public onlyOwner
            enoughApprovals(abi.encodePacked("WITHDRAW_BALANCE", _contractAddress, _amount, _toAddress)) {
        require(_contractAddress != address(0));
        IERC20 token = IERC20(_contractAddress);
        require(token.transfer(_toAddress, _amount), "Staking: Token withdrawal failed");
    }
}
