// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

import { GrantFactory } from '../GrantFactory.sol';

abstract contract GrantStore {
	enum ProjectStatus {
		Normal,
		Restricted
	}

	struct Project {
		uint256 createAt;
		mapping (address => uint256) votes;
		uint256 totalVotes;
		uint256 grants;
		uint256 supportArea;
		uint256 withdrew;
		ProjectStatus status;
	}

	GrantFactory public factory;
	address payable public owner;

	uint256[] public consIdx;
	bytes[] public consParams;

	uint256 public startTime;
	uint256 public endTime;
	bool public roundEnd;

	address internal _acceptToken;
	uint256 public basicVotingUnit;

	mapping(uint256 => Project) internal _projects;
	uint256[] internal _projectList;

	uint256 public supportPool;
	uint256 public preTaxSupportPool;
	mapping(uint256 => mapping(uint256 => address)) public voter;
	mapping(uint256 => uint256) public votesCount;
	mapping(uint256 => mapping(address => uint256)) internal _votesRecord;

	bool public initialized;
	bool internal _rentrancyLock;

	// ProgressiveTaxCtrl
	uint256 internal _totalSupportArea;
	uint256 internal _topArea;
}
