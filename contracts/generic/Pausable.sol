// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;


contract Pausable {

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