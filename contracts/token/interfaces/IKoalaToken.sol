// SPDX-License-Identifier: MIT


pragma solidity 0.6.6;

interface IKoalaToken {
  function transferAll(address _to) external;
  function lockOf(address _account) external view returns (uint256);
  function endReleaseBlock() external view returns (uint256);
  function unlock() external;
}
