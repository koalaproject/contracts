// SPDX-License-Identifier: MIT


pragma solidity 0.6.6;

import "../../../openzeppelin/contracts/token/ERC20/IERC20.sol";

// Making the original MasterChef as an interface leads to compilation fail.
// Use Contract instead of Interface here
contract ICherryMasterChef {
  // Info of each user.
  struct UserInfo {
    uint256 amount; // How many LP tokens the user has provided.
    uint256 rewardDebt; // Reward debt. See explanation below.
  }

  // Info of each pool.
  struct PoolInfo {
    IERC20 lpToken; // Address of LP token contract.
    uint256 allocPoint; // How many allocation points assigned to this pool. SUSHIs to distribute per block.
    uint256 lastRewardBlock; // Last block number that SUSHIs distribution occurs.
    uint256 accCherryPerShare; // Accumulated SUSHIs per share, times 1e12. See below.
  }

  address public cherry;

  // Info of each user that stakes LP tokens.
  PoolInfo[] public poolInfo;
  mapping(uint256 => mapping(address => UserInfo)) public userInfo;

  // Deposit LP tokens to MasterChef for SUSHI allocation.
  function deposit(uint256 _pid, uint256 _amount) external {}

  // Withdraw LP tokens from MasterChef.
  function withdraw(uint256 _pid, uint256 _amount) external {}

  function pendingCherry(uint256 _pid, address _user) external view returns (uint256) {}

  // Deposit CHERRY to the pool (0)
  function enterStaking(uint256 _amount) public {}

  // Withdraw CHERRY from the pool
  function leaveStaking(uint256 _amount) public {}

  function poolLength() external view returns (uint256) {}
}
