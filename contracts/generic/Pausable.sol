// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;


contract Pausable {0x4C690fCbc28d8535203F206eaf5dF7Cef6BEF6E3

  bool public paused = false;
  constructor() {}

  modifier notPaused() {
    require(!paused, "TimeMultisig: Contract is paused");
    _;
  }

  function pause(bool _newPauseState) public virtual {
    paused = _newPauseState;
  }

}