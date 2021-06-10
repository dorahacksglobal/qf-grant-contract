// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

interface IDORAID {
  function statusOf(address _user) external view returns (bool authenticated, uint256 stakingAmount, uint256 stakingEndTime);
}
