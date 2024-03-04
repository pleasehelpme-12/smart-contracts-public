// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../generic/TimeMultisig.sol";


contract VestingFactory is TimeMultisig {

  uint private constant MAX_VESTING_TIME = 4 * 365 days;

  IERC20 private immutable visToken;
  mapping(address => bool) private vestings;
  mapping(uint => bool) private vestingIds;
  address public withdrawalAddress;

  event VestingCreated(address vestingAddress, uint id, uint visAmount, uint unlockTimestamp);
  event VestingWithdrawn(address vestingAddress, address toAddress);

  /**
   * @dev Constructor to initialize the VestingFactory contract.
   * @param visTokenAddress The address of the VIS token contract.
   * @param _owners The addresses of the owners for multisig operations.
   * @param _requiredApprovals The number of required approvals for multisig operations.
   * @param _gracePeriod The grace period for multisig operations.
   */
  constructor(address visTokenAddress, address[] memory _owners, uint _requiredApprovals, uint _gracePeriod)
  TimeMultisig(_owners, _requiredApprovals, _gracePeriod) {
    visToken = IERC20(visTokenAddress);
  }

  /**
   * @dev Creates a new vesting contract.
   * @param visAmount The amount of VIS tokens to be vested.
   * @param id The unique identifier for the vesting contract.
   * @param unlockTimestamp The timestamp when the vested tokens can be withdrawn.
   */
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

  /**
   * @dev Performs withdrawal of vested tokens from a vesting contract.
   * @param vestingAddress The address of the vesting contract.
   */
  function doWithdraw(address vestingAddress) public onlyOwner {
    require(withdrawalAddress != address(0), "VestingFactory: Invalid withdrawal address");
    require(vestings[vestingAddress], "VestingFactory: No vesting on given address");

    VisVesting vesting = VisVesting(vestingAddress);
    vestings[vestingAddress] = false;

    vesting.withdraw(visToken, withdrawalAddress);

    emit VestingWithdrawn(vestingAddress, withdrawalAddress);
  }

  /**
   * @dev Performs withdrawals of vested tokens from multiple vesting contracts.
   * @param vestingAddresses An array of vesting contract addresses.
   */
  function doWithdraws(address[] memory vestingAddresses) external onlyOwner {
    for (uint i = 0; i < vestingAddresses.length; i++) {
      doWithdraw(vestingAddresses[i]);
    }
  }

  /**
   * @dev Sets the withdrawal address for vested tokens.
   * @param _newWithdrawalAddress The new withdrawal address.
   */
  function setWithdrawalAddress(address _newWithdrawalAddress) external onlyOwner
      enoughApprovals(abi.encodePacked("SET_WITHDRAWAL_ADDRESS", _newWithdrawalAddress)) {
    withdrawalAddress = _newWithdrawalAddress;
  }

}

/**
 * @title VisVesting
 * @dev A simple vesting contract for holding and releasing vested tokens.
 */
contract VisVesting {

  address owner;
  uint public id;
  uint public unlockTimestamp;

  /**
   * @dev Constructor to initialize the VisVesting contract.
   * @param _id The unique identifier for the vesting contract.
   * @param _unlockTimestamp The timestamp when the vested tokens can be withdrawn.
   */
  constructor(uint _id, uint _unlockTimestamp) {
    owner = msg.sender;
    id = _id;
    unlockTimestamp = _unlockTimestamp;
  }

  /**
   * @dev Withdraws vested tokens from the contract.
   * @param token The ERC20 token to be withdrawn.
   * @param toAddress The address to which the tokens will be transferred.
   */
  function withdraw(IERC20 token, address toAddress) external {
    require(owner == msg.sender, "Vesting: You are not authorized");
    require(unlockTimestamp <= block.timestamp, "Vesting: Vesting still in progress");
    require(token.transfer(toAddress, token.balanceOf(address(this))), "Vesting: Token transfer failed");
  }

}
