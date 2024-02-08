### TimeMultisig
Smart contract containing functionality to restrict access to 
sensitive function to a single party and requiring an approval of multiple 
verified parties to allow a certain function call.
- During an initialization 3 parameters must be specified:
  - **owners**: list of addresses allowed to give an approval of an action
  - **requiredApprovals**: number of required approvals to allow an action
  - **gracePeriod**: period in seconds within which the approvals must be submitted
- Access to functions using **_enoughApprovals_** modifier will only be allowed
if at least **_{requiredApprovals}_** of **_{owners}_** submitted their 
approvals within **_{gracePeriod}_**.
- Owners can submit their approvals for the upcoming action by calling function _approve_.
- Each successful call of such function immediately revokes all approvals to
forbid further calls with same set of approvals.
- If action has not yet been performed, owner can revoke his previously submitted approval
by calling function _revoke_.
- If action has not yet been performed, any owner can revoke approvals of all owners 
by calling function _revokeAll_, if there is a suspicion of fraudelent activity.
- Owners can add a new owner, remove one of the current owners or 
replace an owner with a new one by submiting their approvals and then calling 
 function _addOwner_, _removeOwner_ or _replaceOwner_ respectively.
- Owners can change required number of approvals or grace period within which they must be submitted 
for each subsequent action by, again, submitting their approvals and calling function 
_changeRequirement_ with a new number of required approvals or _changeGracePeriod_ with
new period setting in seconds, respectively.