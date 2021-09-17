// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

import { IERC20 } from "./interface/IERC20.sol";
import { GrantFactory } from "./GrantFactory.sol";

import { GrantStore } from "./libs/store.sol";
import { Controller } from "./controllers/base.sol";

library SafeMath {
	function add(uint256 a, uint256 b) internal pure returns (uint256) {
		uint256 c = a + b;
		assert(c >= a);
		return c;
	}
	function mul(uint256 a, uint256 b) internal pure returns (uint256) {
		if (b == 0) {
			return 0;
		}
		uint256 c = a * b;
		assert(c / b == a);
		return c;
	}
}

contract Grant is GrantStore {
	using SafeMath for uint256;

  uint256 private constant UNIT = 1000000;

	function initialize (
		GrantFactory _factory,
		address payable _owner,
		uint256[] memory _params, // start, end, votingUnit
		address _token,
		uint256[] memory _consIdx,
		bytes[] memory _consParams
	) external {
		require(!initialized);
		require(_owner != address(0));
		require(_consIdx.length == _consParams.length);
		initialized = true;

		factory = _factory;
		owner = _owner;
		startTime = _params[0];
		endTime = _params[1];
		basicVotingUnit = _params[2];
		_acceptToken = _token;
		for (uint256 i = 0; i < _consIdx.length; i++) {
			consIdx.push(_consIdx[i]);
			consParams.push(_consParams[i]);
		}
	}

	event BanProject(uint256 indexed project, ProjectStatus status);
	event Vote(address indexed account, uint256 indexed project, uint256 vote);
	 
	modifier onlyOwner() {
		require(msg.sender == owner);
		_;
	}

	/**
	 * @dev Prevents a contract from calling itself, directly or indirectly.
	 */
	modifier nonReentrant() {
		require(!_rentrancyLock);
		_rentrancyLock = true;
		_;
		_rentrancyLock = false;
	}

	function allProjects(uint256) external view returns (uint256[] memory projects) {
		return _projectList;
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

	// function dangerSetTime(uint256 _start, uint256 _end) external onlyOwner {
	// 	require(!roundEnd);
	// 	require(_start < _end);

	// 	startTime = _start;
	// 	endTime = _end;
	// }

	// function dangerSetArea(uint256 _projectId, uint256 _supportArea) external onlyOwner {
	// 	Project storage project = _projects[_projectId];
	// 	require(!roundEnd);
	// 	require(project.status == ProjectStatus.Normal);

	// 	_totalSupportArea = _totalSupportArea.add(_supportArea) - project.supportArea;
	// 	project.supportArea = _supportArea;
	// }

	function roundOver() external onlyOwner {
		require(block.timestamp > endTime && endTime > 0);
		roundEnd = true;
	}

	function changeOwner(address payable _newOwner) external onlyOwner {
		require(_newOwner != address(0));
		owner = _newOwner;
	}

	function banProject(uint256 _projectId, ProjectStatus _status) external onlyOwner {
		Project storage project = _projects[_projectId];
		require(!roundEnd);
		require(project.status != _status);
		if (_status == ProjectStatus.Normal) {
			_totalSupportArea = project.supportArea + _totalSupportArea;
		} else {
			_totalSupportArea -= project.supportArea;
		}
		project.status = _status;
		emit BanProject(_projectId, _status);
	}

	function donate(uint256 _amount) public nonReentrant payable {
		require(!roundEnd);

		uint256 fee = factory.tax(_amount);
		if (_isERC20Round()) {
			address sender = msg.sender;
			if (sender == address(factory)) {
				sender = owner;
			}
			IERC20 acceptToken = IERC20(_acceptToken);
			factory.collectToken(acceptToken, sender, _amount);
		} else {
			require(_amount == msg.value);
			payable(address(factory)).transfer(fee);
		}

		uint256 support = _amount - fee;
		supportPool += support;
		preTaxSupportPool += _amount;
	}

	function uploadProject(uint256 _projectId) external {
		require(block.timestamp > startTime);
		require(block.timestamp < endTime);
		require(address(uint160(_projectId)) == msg.sender);
		Project storage project = _projects[_projectId];
		require(project.createAt == 0);
		project.createAt = block.timestamp;
		_projectList.push(_projectId);
	}

	function vote(uint256 _projectId, uint256 _votes) external nonReentrant payable {
		require(block.timestamp < endTime);
		Project storage project = _projects[_projectId];
		require(project.totalVotes < 1e30);

		uint256 cost = _votingCost(msg.sender, project, _votes);
		uint256 fee = factory.tax(cost);
		uint256 grants = cost - fee;

		if (_isERC20Round()) {
			IERC20 acceptToken = IERC20(_acceptToken);
			factory.collectToken(acceptToken, msg.sender, cost);
		} else {
			require(msg.value >= cost);
			uint256 rest = msg.value - grants;
			payable(address(factory)).transfer(rest);
		}

		uint256 voted = project.votes[msg.sender];
		project.votes[msg.sender] += _votes;
		project.grants += grants;
		_votesRecord[_projectId][msg.sender] += grants;

		uint256 addedArea = _votes * (project.totalVotes - voted) * UNIT;

		for (uint256 i = 0; i < consIdx.length; i++) {
			(bool ok, bytes memory data) = address(factory.controller(consIdx[i])).delegatecall(
				abi.encodeWithSignature("handleVote(uint256,uint256,uint256,address)", i, _projectId, _votes, msg.sender)
			);
			require(ok);
			(bool pass, uint256 k) = abi.decode(data, (bool, uint256));
			require(pass);
			addedArea = addedArea * k / UNIT;
		}

		project.totalVotes += _votes;
		project.supportArea = addedArea + project.supportArea;
		if (project.status == ProjectStatus.Normal) {
			_totalSupportArea = addedArea + _totalSupportArea;
		}

		if (project.supportArea > _topArea) {
			_topArea = project.supportArea;
		}

		uint256 vcs = votesCount[_projectId];
		voter[_projectId][vcs] = msg.sender;
		votesCount[_projectId] = vcs + 1;

		emit Vote(msg.sender, _projectId, _votes);
	}

	function takeOutGrants(uint256 _projectId, uint256 _amount) external nonReentrant {
		require(address(uint160(_projectId)) == msg.sender);
		Project storage project = _projects[_projectId];
		(uint256 rest, ) = grantsOf(_projectId);
		require(rest >= _amount);

		project.withdrew += _amount;

		if (_isERC20Round()) {
			IERC20 acceptToken = IERC20(_acceptToken);
			require(acceptToken.transfer(msg.sender, _amount));
		} else {
			payable(msg.sender).transfer(_amount);
		}
	}

	function _votingCost(address _from, Project storage project, uint256 _votes) internal view returns (uint256 cost) {
		uint256 voted = project.votes[_from];
		uint256 votingPoints = _votes.mul(_votes.add(1)) / 2;
		votingPoints = votingPoints.add(_votes.mul(voted));
		cost = votingPoints.mul(basicVotingUnit);
	}

	function _isERC20Round() internal view returns (bool) {
		return _acceptToken != address(0);
	}

	receive() external payable {
		require(!_isERC20Round());
		donate(msg.value);
	}
}
