// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../generic/TimeMultisig.sol";


contract VestingFactory is AccessControl, TimeMultisig {

  uint private constant MAX_VESTING_TIME = 4 * 365 days;

  IERC20 private immutable visToken;
  mapping(address => bool) private vestings;
  
  event VestingCreated(address vestingAddress, uint id, uint visAmount, uint unlockTimestamp);
  event VestingWithdrawn(address vestingAddress, address toAddress);

  constructor(address visTokenAddress, address[] memory _owners, uint _requiredApprovals, uint _gracePeriod)
  TimeMultisig(_owners, _requiredApprovals, _gracePeriod) {
    visToken = IERC20(visTokenAddress);

    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
  }
 
  function createVesting(uint visAmount, uint id, uint unlockTimestamp) external {
    require(visAmount > 0, "no VIS");
    require(unlockTimestamp >= block.timestamp, "past unlockTimestamp");
    require(unlockTimestamp - block.timestamp <= MAX_VESTING_TIME, "too distant unlockTimestamp");
  
    address vestingAddress = address(new VisVesting(id, unlockTimestamp));
    vestings[vestingAddress] = true;
  
    require(visToken.transferFrom(msg.sender, vestingAddress, visAmount), "VIS transfer failed");

    emit VestingCreated(vestingAddress, id, visAmount, unlockTimestamp);
  }

  function doWithdraw(address vestingAddress, address toAddress) public onlyOwner enoughApprovals {
    require(vestings[vestingAddress], "no vesting on given address");
    
    VisVesting vesting = VisVesting(vestingAddress);
    vestings[vestingAddress] = false;

    vesting.withdraw(visToken, toAddress);

    emit VestingWithdrawn(vestingAddress, toAddress);
  }

  function doWithdraws(address[] memory vestingAddresses, address toAddress) external onlyOwner enoughApprovals {
    for (uint i = 0; i < vestingAddresses.length; i++) {
      doWithdraw(vestingAddresses[i], toAddress);
    }
  }

}

contract VisVesting {

  address owner;
  uint public id;
  uint public unlockTimestamp;

  constructor(uint _id, uint _unlockTimestamp) {
    owner = msg.sender;
    id = _id;
    unlockTimestamp = _unlockTimestamp;
  }

  function withdraw(IERC20 token, address toAddress) external {
    require(owner == msg.sender, "only owner");
    require(unlockTimestamp <= block.timestamp, "vesting in progress");
    require(token.transfer(toAddress, token.balanceOf(address(this))), "VIS transfer");
  }

}
