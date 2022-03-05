// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract Vesting is AccessControl {

    uint256 private _totalLock;
    uint256 public initialUnlockAtBlock;
    uint256 public fullUnlockAtBlock;
     IERC20 private supaToken = IERC20(0x44125Bc412077886e79cC3638fb7cf1e32701031); //can use standard openzeppelin erc20 contract to test
    bytes32 public constant AUTHORIZED_ROLE = keccak256("AUTHORIZED_ROLE");


    mapping(address => uint256) private _locks;
    mapping(address => uint256) private _lastWithdrawalBlock;

    event Lock(address indexed to, uint256 value);
    event Unlock(address indexed to, uint256 value);


    constructor(
      uint256 _initialUnlockAtBlock,
      uint256 _fullUnlockAtBlock
    )   {
        initialUnlockAtBlock = _initialUnlockAtBlock;
        fullUnlockAtBlock = _fullUnlockAtBlock;
         _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(AUTHORIZED_ROLE, msg.sender);

    }

    
    // Update the initialUnlockAtBlock
    function lockFromUpdate(uint256 _newLockFrom) public onlyRole(DEFAULT_ADMIN_ROLE) {
        initialUnlockAtBlock = _newLockFrom;
    }

    // Update the fullUnlockAtBlock
    function lockToUpdate(uint256 _newLockTo) public onlyRole(DEFAULT_ADMIN_ROLE) {
        fullUnlockAtBlock = _newLockTo;
    }


    function totalLock() public view returns (uint256) {
        return _totalLock;
    }

    function tokensVested() public view returns (uint256) {
        return  supaToken.balanceOf(address(this));
    }
   
    function lockOf(address _holder) public view returns (uint256) {
        return _locks[_holder];
    }

    function lastWithdrawalBlock(address _holder) public view returns (uint256) {
        return _lastWithdrawalBlock[_holder];
    }

    function lock(address _holder, uint256 _amount) public onlyRole(AUTHORIZED_ROLE) returns(bool){
        
        if(_holder == address(0)){
            return false;
        }
        _locks[_holder] = _locks[_holder]+_amount;
        _totalLock = _totalLock+_amount;
        if (_lastWithdrawalBlock[_holder] < initialUnlockAtBlock) {
            _lastWithdrawalBlock[_holder] = initialUnlockAtBlock;
        }
       return true;
    }

    function canUnlockAmount(address _holder) public view returns (uint256) {
        if (block.number < initialUnlockAtBlock) {
            return 0;
        } else if (block.number >= fullUnlockAtBlock) {
            return _locks[_holder];
        } else {
            uint256 releaseBlock = block.number-_lastWithdrawalBlock[_holder];
            uint256 numberLockBlock =
                fullUnlockAtBlock-_lastWithdrawalBlock[_holder];
            return _locks[_holder]*(releaseBlock)/(numberLockBlock);
        }
    }


    // Unlocks some locked tokens immediately.
    function unlockForUser(address account, uint256 amount) public onlyRole(AUTHORIZED_ROLE) {
        // First we need to unlock all tokens the address is eligible for.
        uint256 pendingLocked = canUnlockAmount(account);
        if (pendingLocked > 0) {
            _unlock(account, pendingLocked);
        }

        // Now that that's done, we can unlock the extra amount passed in.
        _unlock(account, amount);
    }

    function unlock() public {
        uint256 amount = canUnlockAmount(msg.sender);
        _unlock(msg.sender, amount);
    }

    function _unlock(address holder, uint256 amount) internal {
        require(_locks[holder] > 0, "Insufficient locked tokens");

        // Make sure they aren't trying to unlock more than they have locked.
        if (amount > _locks[holder]) {
            amount = _locks[holder];
        }

        // If the amount is greater than the total balance, set it to max.
        if (amount > supaToken.balanceOf(address(this))) {
            amount = supaToken.balanceOf(address(this));
        }
          supaToken.transfer(holder, amount);

        _locks[holder] = _locks[holder]-amount;
        _lastWithdrawalBlock[holder] = block.number;
        _totalLock = _totalLock-amount;

        emit Unlock(holder, amount);
    }

   
}
  
