// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

import { IERC20 } from "./interface/IERC20.sol";

import { GrantStore } from "./libs/store.sol";

contract GrantModel is GrantStore {
	function allProjects(uint256) external view returns (uint256[] memory projects) {
		return _projectList;
	}

	function projectStatus(uint256[] memory pIds) external view returns (ProjectStatus[] memory status) {
		status = new ProjectStatus[](pIds.length);
		for (uint256 i = 0; i < pIds.length; i++) {
			Project storage project = _projects[pIds[i]];
			status[i] = project.status;
		}
	}

	function rankingList(uint256) external view returns (
		uint256 unit,
		uint256[] memory projects,
		uint256[] memory votes,
		uint256[] memory support,
		uint256[] memory grants
	) {
		if (_totalSupportArea != 0) {
			unit = supportPool / _totalSupportArea;
		}
		projects = _projectList;
		votes = new uint256[](projects.length);
		support = new uint256[](projects.length);
		grants = new uint256[](projects.length);
		for (uint256 i = 0; i < projects.length; i++) {
			uint256 pid = projects[i];
			Project storage project = _projects[pid];
			votes[i] = project.totalVotes;
			support[i] = project.status == ProjectStatus.Normal ? project.supportArea : 0;
			grants[i] = project.grants;
		}
	}

	function roundInfo(uint256) external view returns (
		uint256 startFrom,
		uint256 endAt,
		uint256 support,
		uint256 preTaxSupport
	) {
		return (
			startTime,
			endTime,
			supportPool,
			preTaxSupportPool
		);
	}

	function acceptTokenInfo() external view returns (
		address token,
		string memory symbol,
		uint256 decimals
	) {
		require(_isERC20Round());

		IERC20 acceptToken = IERC20(_acceptToken);
		token = address(acceptToken);
		symbol = acceptToken.symbol();
		decimals = acceptToken.decimals();
	}

	function votingCost(address _from, uint256 _projectId, uint256 _votes) external view returns (uint256 cost, bool votable) {
		Project storage project = _projects[_projectId];
		votable = block.timestamp < endTime;
		cost = _votingCost(_from, project, _votes);
	}

	function grantsOf(uint256 _projectId) public view returns (uint256 rest, uint256 total) {
		Project storage project = _projects[_projectId];
		if (!roundEnd) {
			return (0, 0);
		}
		total = project.grants;
		if (project.status == ProjectStatus.Normal && _totalSupportArea != 0) {
			total += project.supportArea * supportPool / _totalSupportArea;
		}
		require(total >= project.withdrew);
		rest = total - project.withdrew;
	}

	function projectOf(uint256 _projectId) external view returns (
		uint256 createAt,
		uint256 totalVotes,
		uint256 grants,
		uint256 supportArea,
		uint256 withdrew
	) {
		Project storage project = _projects[_projectId];
		createAt = project.createAt;
		totalVotes = project.totalVotes;
		grants = project.grants;
		supportArea = project.status == ProjectStatus.Normal ? project.supportArea : 0;
		withdrew = project.withdrew;
	}

	function votesOf(uint256 _projectId, address _user) external view returns (uint256) {
		return _votesRecord[_projectId][_user];
	}

	function _matchingOf(Project storage project) internal view returns (uint256) {
		if (_totalSupportArea == 0) {
			return 0;
		}
		if (project.status != ProjectStatus.Normal) {
			return 0;
		}
		return project.supportArea * supportPool / _totalSupportArea;
	}

	function _votingCost(address _from, Project storage project, uint256 _votes) internal view returns (uint256 cost) {
		require(_votes < 1e24, "safemath");
		uint256 voted = project.votes[_from];
		require(voted < 1e24, "safemath");
		uint256 votingPoints = _votes * (_votes + 1) / 2;
		votingPoints = _votes * voted + votingPoints;
		cost = votingPoints * basicVotingUnit;
	}

	function _isERC20Round() internal view returns (bool) {
		return _acceptToken != address(0);
	}
}
