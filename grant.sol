// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

import { IERC20 } from "./interface/IERC20.sol";
import { GrantFactory } from "./GrantFactory.sol";
import { GrantModel } from "./GrantModel.sol";
import { Controller } from "./controllers/base.sol";

contract Grant is GrantModel {
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
		require(_params[2] < 1e24, "safemath");
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

	function vote(uint256 _projectId, uint256 _votes) public nonReentrant payable {
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

		project.grants += grants;
		_votesRecord[_projectId][msg.sender] += grants;

		_processVoteAndArea(_projectId, msg.sender, _votes);

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

	function _processVoteAndArea(uint256 _projectId, address sender, uint256 _votes) internal {
		Project storage project = _projects[_projectId];
		uint256 voted = project.votes[sender];
		project.votes[sender] += _votes;

		uint256 addedArea = _votes * (project.totalVotes - voted) * UNIT;

		for (uint256 i = 0; i < consIdx.length; i++) {
			(bool ok, bytes memory data) = address(factory.controller(consIdx[i])).delegatecall(
				abi.encodeWithSignature("handleVote(uint256,uint256,uint256,address)", i, _projectId, _votes, sender)
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
	}

	receive() external payable {
		require(!_isERC20Round());
		donate(msg.value);
	}
}
