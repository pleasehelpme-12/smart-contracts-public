// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;


contract TimeMultisig {
  address[] public owners;
  mapping(address => uint) public approvals;
  mapping(address => bool) public isOwner;
  uint public requiredApprovals; // required amount of approvals to allow the transaction execution
  uint public gracePeriod; // period within which approvals must be submitted - recommended: 10 minutes

  constructor(address[] memory _owners, uint _requiredApprovals, uint _gracePeriod) {
    owners = _owners;
    for (uint i=0; i<owners.length; i++) {
      isOwner[owners[i]] = true;
    }

    _changeRequirement(_requiredApprovals);
    _changeGracePeriod(_gracePeriod);
  }

  modifier onlyOwner() {
    require(isOwner[msg.sender], "TimeMultisig: Not authorized owner");
    _;
  }

  modifier enoughApprovals() {
    approvals[msg.sender] = block.timestamp;

    uint count = 0;
    for (uint i=0; i<owners.length; i++) {
      if (approvals[owners[i]] > block.timestamp - gracePeriod) {
        count++;
      }
    }
    require(count >= requiredApprovals, "TimeMultisig: Not enough approvals");

    revokeAll(); // Revoke all approvals upon validation, to disable multiple consequent calls
    _;
  }

  function changeRequirement(uint _newRequiredApprovals) public onlyOwner enoughApprovals {
    _changeRequirement(_newRequiredApprovals);
  }

  function changeGracePeriod(uint _newGracePeriod) public onlyOwner enoughApprovals {
    _changeGracePeriod(_newGracePeriod);
  }

  function _changeRequirement(uint _newRequiredApprovals) internal {
    require(_newRequiredApprovals <= owners.length, "TimeMultisig: Required approvals cannot exceed number of owners");
    requiredApprovals = _newRequiredApprovals;
  }

  function _changeGracePeriod(uint _newGracePeriod) internal {
    require(_newGracePeriod >= 60, "TimeMultisig: Grace period cannot be less than 60 seconds");
    gracePeriod = _newGracePeriod;
  }

  function addOwner(address _newOwner) public onlyOwner enoughApprovals {
    require(_newOwner != address(0), "TimeMultisig: Not valid address");
    require(isOwner[_newOwner] == false, "TimeMultisig: Owner already exists");
    owners.push(_newOwner);
    isOwner[_newOwner] = true;
  }

  function removeOwner(address _oldOwner) public onlyOwner enoughApprovals {
    require(isOwner[_oldOwner], "TimeMultisig: Owner does not exist");
    isOwner[_oldOwner] = false;
    for (uint i=0; i<owners.length - 1; i++)
      if (owners[i] == _oldOwner) {
        owners[i] = owners[owners.length - 1];
        break;
      }
    owners.pop();

    if (requiredApprovals > owners.length){
      changeRequirement(owners.length);
    }
  }

  function replaceOwner(address _oldOwner, address _newOwner) public onlyOwner enoughApprovals {
    require(_newOwner != address(0), "TimeMultisig: Not valid address");
    require(isOwner[_oldOwner], "TimeMultisig: Owner does not exist");
    require(isOwner[_newOwner] == false, "TimeMultisig: Owner already exists");
    for (uint i=0; i<owners.length; i++) {
      if (owners[i] == _oldOwner) {
        owners[i] = _newOwner;
        break;
      }
    }
    isOwner[_oldOwner] = false;
    isOwner[_newOwner] = true;
  }

  function approve() public onlyOwner {
    approvals[msg.sender] = block.timestamp;
  }

  function revoke() public onlyOwner {
    if (approvals[msg.sender] > 0) {
      delete approvals[msg.sender];
    }
  }

  function revokeAll() public onlyOwner {
    for (uint i=0; i<owners.length; i++) {
      delete approvals[owners[i]];
    }
  }
}