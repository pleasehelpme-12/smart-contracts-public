// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Pausable} from "./Pausable.sol";

contract TimeMultisig is Pausable {
    /// @dev Emitted when the required number of approvals is changed.
    event RequirementChanged(uint requirement);

    /// @dev Emitted when the grace period is changed.
    event GracePeriodChanged(uint gracePeriod);

    /// @dev Emitted when an approval is submitted.
    event ApprovalSubmitted(address indexed owner, bytes32 data);

    /// @dev Emitted when an approval is revoked.
    event ApprovalRevoked(address indexed owner);

    /// @dev Emitted when a new owner is added.
    event OwnerAdded(address indexed owner);

    /// @dev Emitted when an existing owner is removed.
    event OwnerRemoved(address indexed owner);

    /// @dev List of addresses representing owners of the multisig.
    address[] public owners;

    /// @dev Transaction data that are being approved.
    mapping(address => bytes32) public approvalData;

    /// @dev Mapping to track approvals given by owners.
    mapping(address => uint) public approvals;

    /// @dev Mapping to check if an address is an owner.
    mapping(address => bool) public isOwner;

    /// @dev Required number of approvals to execute a transaction.
    uint public requiredApprovals;

    /// @dev Period within which approvals must be submitted (in seconds).
    uint public gracePeriod;

    /**
     * @dev Constructs the TimeMultisig contract.
     * @param _owners Array of initial owners' addresses.
     * @param _requiredApprovals Number of required approvals.
     * @param _gracePeriod Duration within which approvals must be submitted.
     */
    constructor(address[] memory _owners, uint _requiredApprovals, uint _gracePeriod) Pausable() {
        owners = _owners;
        uint ownersLength = owners.length;
        for (uint i; i<ownersLength; i++) {
            isOwner[owners[i]] = true;
        }

        _changeRequirement(_requiredApprovals);
        _changeGracePeriod(_gracePeriod);
    }

    /// @dev Modifier to allow only owners to call the function.
    modifier onlyOwner() {
        require(isOwner[msg.sender], "TimeMultisig: Not authorized owner");
        _;
    }

    /**
     * @dev Modifier to check if enough approvals have been obtained.
     * @dev This modifier also revokes all approvals upon successful validation.
     */
    modifier enoughApprovals(bytes memory data) {
        approvals[msg.sender] = block.timestamp;
        approvalData[msg.sender] = keccak256(data);

        uint count = 0;
        uint ownersLength = owners.length;
        for (uint i; i<ownersLength; i++) {
            if (approvals[owners[i]] > block.timestamp - gracePeriod
                && approvalData[owners[i]] == keccak256(data)) {
                count++;
            }
        }
        require(count >= requiredApprovals, "TimeMultisig: Not enough approvals");

        revokeAll(); // Revoke all approvals upon validation, to disable multiple consequent calls
        _;
    }

    /**
     * @dev Pauses or unpauses the contract.
     * @param _newPauseState New pause state.
     */
    function pause(bool _newPauseState) public override onlyOwner {
        super.pause(_newPauseState);
    }

    /**
     * @dev Changes the required number of approvals.
     * @param _newRequiredApprovals New required number of approvals.
     */
    function changeRequirement(uint _newRequiredApprovals) public onlyOwner
            enoughApprovals(abi.encodePacked("CHANGE_REQUIREMENT", _newRequiredApprovals)) {
        _changeRequirement(_newRequiredApprovals);
    }

    /**
     * @dev Changes the grace period for approvals.
     * @param _newGracePeriod New grace period in seconds.
     */
    function changeGracePeriod(uint _newGracePeriod) public onlyOwner
            enoughApprovals(abi.encodePacked("CHANGE_GRACE_PERIOD", _newGracePeriod)) {
        _changeGracePeriod(_newGracePeriod);
    }

    /**
     * @dev Internal function to change the required number of approvals.
     * @param _newRequiredApprovals New required number of approvals.
     */
    function _changeRequirement(uint _newRequiredApprovals) internal {
        require(_newRequiredApprovals <= owners.length, "TimeMultisig: Required approvals cannot exceed number of owners");
        requiredApprovals = _newRequiredApprovals;

        emit RequirementChanged(_newRequiredApprovals);
    }

    /**
     * @dev Internal function to change the grace period for approvals.
     * @param _newGracePeriod New grace period in seconds.
     */
    function _changeGracePeriod(uint _newGracePeriod) internal {
        require(_newGracePeriod >= 60, "TimeMultisig: Grace period cannot be less than 60 seconds");
        require(_newGracePeriod <= 900, "TimeMultisig: Grace period must be less than 900 seconds");
        gracePeriod = _newGracePeriod;

        emit GracePeriodChanged(_newGracePeriod);
    }

    /**
     * @dev Adds a new owner to the multisig.
     * @param _newOwner Address of the new owner.
     */
    function addOwner(address _newOwner) public onlyOwner
            enoughApprovals(abi.encodePacked("ADD_OWNER", _newOwner)) {
        require(_newOwner != address(0), "TimeMultisig: Not valid address");
        require(isOwner[_newOwner] == false, "TimeMultisig: Owner already exists");
        owners.push(_newOwner);
        isOwner[_newOwner] = true;

        emit OwnerAdded(_newOwner);
    }

    /**
     * @dev Removes an existing owner from the multisig.
     * @param _oldOwner Address of the owner to be removed.
     */
    function removeOwner(address _oldOwner) public onlyOwner
            enoughApprovals(abi.encodePacked("REMOVE_OWNER", _oldOwner)) {
        require(isOwner[_oldOwner], "TimeMultisig: Owner does not exist");
        isOwner[_oldOwner] = false;
        uint ownersLength = owners.length;
        for (uint i; i<ownersLength - 1; i++)
            if (owners[i] == _oldOwner) {
                owners[i] = owners[ownersLength - 1];
                break;
            }
        owners.pop();

        if (requiredApprovals > ownersLength){
            changeRequirement(ownersLength);
        }

        emit OwnerRemoved(_oldOwner);
    }

    /**
     * @dev Replaces an existing owner with a new owner.
     * @param _oldOwner Address of the owner to be replaced.
     * @param _newOwner Address of the new owner.
     */
    function replaceOwner(address _oldOwner, address _newOwner) public onlyOwner
            enoughApprovals(abi.encodePacked("REPLACE_OWNER", _oldOwner, _newOwner)) {
        require(_newOwner != address(0), "TimeMultisig: Not valid address");
        require(isOwner[_oldOwner], "TimeMultisig: Owner does not exist");
        require(isOwner[_newOwner] == false, "TimeMultisig: Owner already exists");
        uint ownersLength = owners.length;
        for (uint i; i<ownersLength; i++) {
            if (owners[i] == _oldOwner) {
                owners[i] = _newOwner;
                break;
            }
        }
        isOwner[_oldOwner] = false;
        isOwner[_newOwner] = true;

        emit OwnerAdded(_newOwner);
        emit OwnerRemoved(_oldOwner);
    }

    /// @dev Gives an approval for the transaction.
    function approve(bytes memory data) public onlyOwner {
        approvalData[msg.sender] = keccak256(data);
        approvals[msg.sender] = block.timestamp;
        emit ApprovalSubmitted(msg.sender, keccak256(data));
    }

    /// @dev Revokes an approval for the transaction.
    function revoke() public onlyOwner {
        if (approvals[msg.sender] > 0) {
            delete approvals[msg.sender];
            delete approvalData[msg.sender];
        }
        emit ApprovalRevoked(msg.sender);
    }

    /// @dev Revokes all approvals for the transaction.
    function revokeAll() internal {
        uint ownersLength = owners.length;
        for (uint i; i<ownersLength; i++) {
            delete approvals[owners[i]];
            delete approvalData[owners[i]];
        }
    }
}
