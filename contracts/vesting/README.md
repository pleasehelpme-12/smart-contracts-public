### VestingFactory
Smart contract able to lock specified amount of ERC20 tokens 
for specified amount of time
- During an initialization an address of a token that will be 
locked into the contract must be specified.
- Any wallet can create a new vesting and lock specified amount 
of tokens into the contract by calling function _createVesting_.
These tokens will be locked until timestamp specified in _unlockTimestamp_
will be reached. This action will emit an event containing address
of newly deployed vesting contract where tokens will stay locked.
- To withdraw tokens after this timestamp, owners must submit their approvals
and then call the function _doWithdraw_ and specify address of the vesting 
contract they wish to withdraw tokens from and to which address the unlocked 
tokens should be transferred to.
- Owners can perform multiple withdrawals from multiple vesting contract at
once, by calling the function _doWithdraws_.
