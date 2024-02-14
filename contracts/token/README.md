### Vis
Token in compliance with ERC20 standard with additional feature to burn it.

### Launchpad
Launchpad is a smart contract responsible for selling tokens at a calculated
price and immediately locking bought tokens into a staking smart contract.
During initialization token address of VIS token and USDT token (used as payment
method) must be specified, as well as owners of the contract able to perform
authorized actions.

Smart contract contains following methods:
- currentPrice
  - calculates current price in USDT for given amount with respect to slippage caused by the **amount**
    of tokens being bought
- buy
  - checks whether contract contains enough VIS tokens as caller wants to buy
  - transfers required amount of USDT into the contract from caller's 
    wallet
  - approves staking contract to transfer caclulated amount of VIS tokens from this contract.
  - calls staking contract to create staking on caller's behalf
- setStakingContract
  - enables owners to change staking contract to a newer version, if needed
- setPrices
  - enables owners to change startPrice and endPrice, if needed
- withdrawBalance
  - enables owners to withdraw USDT from this contract after successful sale
