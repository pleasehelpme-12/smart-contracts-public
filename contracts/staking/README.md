### Staking
Smart contract responsible for locking staked tokens for preset amount of time.
During initialization token address of VIS tokens and owners able to perform authorized
actions must be specified. Default number of approvals needed is 3 and default grace period
within which the approvals must be submitted is 600 seconds (10 minutes).

To stake, caller must call method **stake** and specify his address or address
he is creating staking account for, amount of VIS tokens to stake and period
they wish to stake the tokens for. They can choose from 1 year period or 2 year
period. At account creation final amount at the end of the stake will be calculated
and saved. If staking account for the address already exists, new deposit
will be added to previous deposit, but the lock will be prolonged and period
will start all over again. If there is interest and eligible bonuses accumulated
from previous deposit and they are not claimed before staking new amount, they 
will be moved to the new period and distributed among the new interest.

Example:
If someone staked 10,000 tokens for 1 year period and after 6 months they 
have accumulated interest of 250 and eligible bonuses of 230 and they stake
another amount, the outstanding amount will be redistributed for the next 12
months and added to the new eligible interest amount. If the second staking
amount is 5,000, after the first month, the example staker will be eligible
for 62.5 tokens plus 40 (480/12) tokens from previously accumulated interest.

**calculateEligibleBonus**
calculates amount for which the staker is eligible. The staker is only eligible
for bonuses deposited during his stakings. All bonuses deposited before creation
of the staking account and all bonuses deposited after his staking has ended (even
if they have not withdrawn the staking account yet) will not be counted in.
In theory, all bonuses are distributed among all stakers at the moment of deposit
according to the size of their account.

**calculateEligibleInterest**
calculate amount of accrued interest from all deposits. Calculation takes into an
account if staking has already ended but is not withdrawn yet.

**claimInterest**
calculates sum of all eligible bonuses and all eligible interest accumulated and
transfer them to owners wallet.

**withdrawStaking**
If staking period has already ended, the staker can call this method and claim 
all of their deposits with all eligible bonuses and interest accumulated. Whole
amount will be transferred to owners wallet.

**setInterest**
enables owners to update interest rates for 1-year and 2-year period.

**bonusDeposit**
enables owners to deposit extra reward for stakers and distribute it among them.

**withdrawBalance**
emergency method for owners to withdraw any tokens or native currency if they 
happened to get locked into the contract.