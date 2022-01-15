// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import { GrantStorage } from "./lib/storage.sol";
import { GrantAdmin } from "./lib/admin.sol";
import { GrantUser } from "./lib/user.sol";

contract Grant is GrantStorage, GrantAdmin, GrantUser {
	event Vote(address indexed account, uint256 indexed project, uint256 vote);

	/**
	 * @dev Prevents a contract from calling itself, directly or indirectly.
	 */
	modifier nonReentrant() {
		require(!_rentrancyLock);
		_rentrancyLock = true;
		_;
		_rentrancyLock = false;
	}

	function initialize (
		address payable _owner
	) external {
		require(!initialized);
		require(_owner != address(0));
		initialized = true;

		owner = _owner;
		currentRound = 1;
		TAX_POINT = 50000;
	}

	function ongoing() public view returns (bool) {
		Round storage round = _rounds[currentRound];
		return round.startAt <= block.timestamp && round.endAt > block.timestamp;
	}

	function votingCost(address _from, uint256 _p, uint256 _votes) public view returns (uint256 cost, bool votable) {
		require(_votes < 1 ether);

		Round storage round = _rounds[currentRound];
		Project storage project = _projects[_p];

		votable =
			project.status == ProjectStatus.Normal &&
			project.participationRoundIdx >= currentRound &&
			ongoing();

		uint256 voted = round.voted[_p][_from];
		uint256 votingPoints = _votes * (_votes + 1) / 2;
		votingPoints += _votes * voted;
		cost = votingPoints * round.votePrice;
	}

	function grantsOf(uint256 _r, uint256 _p) public view returns (uint256) {
		if (_r >= currentRound) return 0;

		Round storage round = _rounds[_r];
		Project storage project = _projects[_p];

		if (round.withdrew[_p]) return 0;
		if (project.validRound > _r) return 0;

		uint256 category = project.categoryIdx;
		if (!round.hasCategory[category]) {
			category = 0;
		}

		uint256 total = round.contribution[_p];

		uint256 totalArea = round.totalAreaCategorial[category];
		if (totalArea != 0) {
			total += round.areas[_p] * round.matchingPoolCategorial[category] / totalArea;
		}
		return total;
	}

	function donate(uint256 _amount, uint256 _category) public nonReentrant payable {
		require(_amount == msg.value);
		
		Round storage round = _rounds[currentRound];
		require(round.hasCategory[_category] || _category == 0);

		uint256 tax = _amount * TAX_POINT / UNIT;

		_tax += tax;
		round.matchingPoolCategorial[_category] += _amount - tax;
	}

	function uploadProject(uint256 _projectId, uint256 _category) external {
		require(address(uint160(_projectId)) == msg.sender);
		Project storage project = _projects[_projectId];
		require(project.status == ProjectStatus.Empty);
	
		project.status = ProjectStatus.Normal;
		project.categoryIdx = _category;
		project.participationRoundIdx = 1 ether; // big enough

		_projectList.push(_projectId);
	}

	function vote(uint256 _p, uint256 _votes) external nonReentrant payable {
		Round storage round = _rounds[currentRound];

		(uint256 cost, bool votable) = votingCost(msg.sender, _p, _votes);
		require(votable);
		require(msg.value >= cost);

		uint256 rest = msg.value - cost;
		if (rest > 0) {
			_tax = _tax + rest;
		}

		uint256 fee = cost * TAX_POINT / UNIT;
		uint256 contribution = cost - fee;
		_tax += fee;

		round.contribution[_p] += contribution;
		
		_processVoteAndArea(round, _p, msg.sender, _votes);

		emit Vote(msg.sender, _p, _votes);
	}

	function _processVoteAndArea(Round storage round, uint256 _p, address _from, uint256 _votes) internal {
		uint256 category = _projects[_p].categoryIdx;
		if (!round.hasCategory[category]) {
			category = 0;
		}

		uint256 totalArea = round.totalAreaCategorial[category];
		uint256 topArea = round.topAreaCategorial[category];
	
		uint256 incArea = _votes * (
			round.votes[_p] - round.voted[_p][_from]
		) * UNIT;

		uint256 area = round.areas[_p];
		if (topArea > 0 && totalArea > 0) {
			if (area > TAX_THRESHOLD) {
				uint256 k1 = area * UNIT / topArea;						// absolutely less than 1
				uint256 k2 = area * UNIT / totalArea;					// absolutely less than 1
				// assert(k1 <= UNIT && k2 <= UNIT);
				uint256 k = UNIT - k1 * k2 / UNIT;

				incArea = incArea * k * k / UNIT / UNIT;
			}
		}
		uint256 newArea = area + incArea;

		round.votes[_p] += _votes;
		round.areas[_p] = newArea;

		round.totalAreaCategorial[category] += incArea;
		if (newArea > topArea) {
			round.topAreaCategorial[category] = newArea;
		}
	}

	function takeOutGrants(uint256 _r, uint256 _p) external nonReentrant {
		require(address(uint160(_p)) == msg.sender);

		uint256 grants = grantsOf(_r, _p);
		require(grants > 0);

		_rounds[_r].withdrew[_p] = true;

		payable(msg.sender).transfer(grants);
	}

	function withdraw() external nonReentrant onlyOwner {
		uint256 amount = _tax;
		_tax = 0;

		owner.transfer(amount);
	}

/**
	function voteSimulation(address _voter, uint256 _projectId, uint256 _votes) external returns (uint256, uint256) {
		require (msg.sender == address(0), "only queries are allowed");

		Project storage project = _projects[_projectId];
		uint256 m0 = _matchingOf(project);
		_processVoteAndArea(_projectId, _voter, 1);
		uint256 m1 = _matchingOf(project);
		_processVoteAndArea(_projectId, _voter, _votes);
		uint256 m2 = _matchingOf(project);
		return (m1 - m0, m2 - m0);
	}

	function _matchingOf(Project storage project) internal view returns (uint256) {
		if (_totalSupportArea == 0) {
			return 0;
		}
		return project.supportArea * supportPool / _totalSupportArea;
	}

	function _votingCost(Round storage round, uint256 _p, address _from, uint256 _votes) internal view returns (uint256 cost) {
		require(_votes < 1 ether);
		uint256 voted = round.voted[_p][_from];
		uint256 votingPoints = _votes * (_votes + 1) / 2;
		votingPoints += _votes * voted;
		cost = votingPoints * round.votePrice;
	}
*/

	receive() external payable {
		donate(msg.value, 0);
	}
}
