// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../generic/TimeMultisig.sol";


contract VestingFactory is AccessControl, TimeMultisig {

  uint private constant MAX_VESTING_TIME = 4 * 365 days;

  IERC20 private immutable visToken;
  mapping(address => bool) private vestings;
  mapping(uint => bool) private vestingIds;
  address public withdrawalAddress;
  
  event VestingCreated(address vestingAddress, uint id, uint visAmount, uint unlockTimestamp);
  event VestingWithdrawn(address vestingAddress, address toAddress);

  constructor(address visTokenAddress, address[] memory _owners, uint _requiredApprovals, uint _gracePeriod)
  TimeMultisig(_owners, _requiredApprovals, _gracePeriod) {
    visToken = IERC20(visTokenAddress);

    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
  }
 
  function createVesting(uint visAmount, uint id, uint unlockTimestamp) external {
    require(vestingIds[id] == false, "VestingFactory: Vesting ID already exists");
    require(visAmount > 0, "VestingFactory: Invalid amount");
    require(unlockTimestamp >= block.timestamp, "VestingFactory: Invalid unlockTimestamp");
    require(unlockTimestamp - block.timestamp <= MAX_VESTING_TIME, "VestingFactory: Too distant unlockTimestamp");
  
    address vestingAddress = address(new VisVesting(id, unlockTimestamp));
    vestings[vestingAddress] = true;
    vestingIds[id] = true;
  
    require(visToken.transferFrom(msg.sender, vestingAddress, visAmount), "VestingFactory: Token transfer failed");

    emit VestingCreated(vestingAddress, id, visAmount, unlockTimestamp);
  }

  function doWithdraw(address vestingAddress) public onlyOwner {
    require(withdrawalAddress != address(0), "VestingFactory: Invalid withdrawal address");
    require(vestings[vestingAddress], "VestingFactory: No vesting on given address");

    VisVesting vesting = VisVesting(vestingAddress);
    vestings[vestingAddress] = false;

    vesting.withdraw(visToken, withdrawalAddress);

    emit VestingWithdrawn(vestingAddress, withdrawalAddress);
  }

  function doWithdraws(address[] memory vestingAddresses) external onlyOwner {
    for (uint i = 0; i < vestingAddresses.length; i++) {
      doWithdraw(vestingAddresses[i]);
    }
  }

  function setWithdrawalAddress(address _newWithdrawalAddress) external onlyOwner enoughApprovals {
    withdrawalAddress = _newWithdrawalAddress;
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
    require(owner == msg.sender, "Vesting: You are not authorized");
    require(unlockTimestamp <= block.timestamp, "Vesting: Vesting still in progress");
    require(token.transfer(toAddress, token.balanceOf(address(this))), "Vesting: Token transfer failed");
  }

}
