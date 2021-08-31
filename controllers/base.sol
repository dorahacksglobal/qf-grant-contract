// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

interface Controller {
	function handleVote(uint256 _idx, uint256 _projectId, uint256 _votes, address _voter) external returns (bool pass, uint256 weight);
}
