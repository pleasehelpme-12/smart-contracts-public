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
- Owners can set withdrawal address, by submitting their approvals and then calling the function _setWithdrawalAddress_.
- To withdraw tokens after this timestamp, an owner must call the function _doWithdraw_ and specify address of the vesting 
contract they wish to withdraw tokens from. Tokens will be withdrawn to pre-set withdrawal address
- Owners can perform multiple withdrawals from multiple vesting contracts at
once, by calling the function _doWithdraws_.
