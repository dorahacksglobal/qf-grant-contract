// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

import { IDORAID } from "./interface/DoraID.sol";
import { IERC20 } from "./interface/IERC20.sol";
import { GrantFactory } from './GrantFactory.sol';

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

contract Grant {
	using SafeMath for uint256;

  IDORAID constant public DORA_ID = IDORAID(0x1234567890123456789012345678901234567890);
	uint256 constant public TAX_POINT = 500;

	bool public initialized;

	address payable public owner;
	GrantFactory public factory;

	uint256 public currentRound = 0;
	uint256 public startTime;
	uint256 public endTime;

	address private _acceptToken;

	uint256 public basicVotingUnit;
	uint256 public votingPower;

	uint256 private _tax;

	struct Project {
		uint256 round;
		uint256 createAt;
		mapping (address => uint256) votes;
		uint256 totalVotes;
		uint256 grants;
		uint256 supportArea;
		uint256 withdrew;
	}

	mapping(uint256 => Project) private _projects;
	uint256[] private _projectList;

	uint256 public supportPool;
	uint256 public preTaxSupportPool;
	uint256 private _totalSupportArea;

	mapping(uint256 => bool) public ban;
	mapping(uint256 => mapping(address => uint256)) private _votesRecord;

	bool public roundEnd;

	function initialize (
		GrantFactory _factory,
		address payable _owner,
		uint256 _start,
		uint256 _end,
		address _token,
		uint256 _votingUnit,
		uint256 _votingPower
	) public {
		require(!initialized);
		initialized = true;

		factory = _factory;
		owner = _owner;
		startTime = _start;
		endTime = _end;
		_acceptToken = _token;
		basicVotingUnit = _votingUnit;
		votingPower = _votingPower;
	}

	event BanProject(uint256 indexed project, bool ban);

	event Vote(address indexed account, uint256 indexed project, uint256 vote);
	 
	modifier onlyOwner() {
		require(msg.sender == owner);
		_;
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
			votes[i] = _projects[pid].totalVotes;
			support[i] = ban[pid] ? 0 : _projects[pid].supportArea;
			grants[i] = ban[pid] ? 0 : _projects[pid].grants;
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

	function votingCost(address _from, uint256 _projectID, uint256 _votes) external view returns (uint256 cost, bool votable) {
		Project storage project = _projects[_projectID];
		votable = project.round == currentRound && block.timestamp < endTime;
		cost = _votingCost(_from, project, _votes);
	}

	function grantsOf(uint256 _projectID) public view returns (uint256 rest, uint256 total) {
		Project storage project = _projects[_projectID];
		if (!roundEnd || ban[_projectID]) {
			return (0, 0);
		}
		total = project.grants;
		if (_totalSupportArea != 0) {
			total = total.add(project.supportArea.mul(supportPool) / _totalSupportArea);
		}
		require(total >= project.withdrew);
		rest = total - project.withdrew;
	}

	function projectOf(uint256 _projectID) external view returns (
		uint256 round,
		uint256 createAt,
		uint256 totalVotes,
		uint256 grants,
		uint256 supportArea,
		uint256 withdrew
	) {
		Project storage project = _projects[_projectID];
		round = project.round;
		createAt = project.createAt;
		totalVotes = project.totalVotes;
		grants = ban[_projectID] ? 0 : project.grants;
		supportArea = ban[_projectID] ? 0 : project.supportArea;
		withdrew = project.withdrew;
	}

	function votesOf(uint256 _projectID, address _user) external view returns (uint256) {
		return _votesRecord[_projectID][_user];
	}

	// function dangerSetTime(uint256 _start, uint256 _end) external onlyOwner {
	// 	require(!roundEnd);
	// 	startTime = _start;
	// 	endTime = _end;
	// }
	// function dangerSetArea(uint256 _projectID, uint256 _supportArea) external onlyOwner {
	// 	Project storage project = _projects[_projectID];
	// 	require(!roundEnd);
	// 	require(!ban[_projectID]);

	// 	_totalSupportArea = _totalSupportArea.add(_supportArea) - project.supportArea;
	// 	project.supportArea = _supportArea;
	// }

	function roundOver() external onlyOwner {
		require(block.timestamp > endTime && endTime > 0);
		roundEnd = true;
	}

	function changeOwner(address payable _newOwner) external onlyOwner {
		owner = _newOwner;
	}

	function banProject(uint256 _projectID, bool _ban) external onlyOwner {
		Project storage project = _projects[_projectID];
		require(!roundEnd);
		require(ban[_projectID] != _ban);
		ban[_projectID] = _ban;
		if (_ban) {
			_totalSupportArea -= project.supportArea;
			_tax += project.grants;
		} else {
			_totalSupportArea = project.supportArea.add(_totalSupportArea);
			_tax -= project.grants;
		}
		emit BanProject(_projectID, _ban);
	}

	function donate(uint256 _amount) public payable {
		require(!roundEnd);

		if (_isERC20Round()) {
			IERC20 acceptToken = IERC20(_acceptToken);
			require(acceptToken.transferFrom(msg.sender, address(this), _amount));
		} else {
			require(_amount == msg.value);
		}

		uint256 fee = _amount.mul(TAX_POINT) / 10000;
		uint256 support = _amount - fee;
		_tax += fee;
		supportPool += support;
		preTaxSupportPool += _amount;
	}

	function uploadProject(uint256 _projectID) external {
		require(block.timestamp > startTime);
		require(block.timestamp < endTime);
		require(address(bytes20(bytes32(_projectID))) == msg.sender);
		Project storage project = _projects[_projectID];
		require(project.createAt == 0);
		project.round = currentRound;
		project.createAt = block.timestamp;
		_projectList.push(_projectID);
	}

	function vote(uint256 _projectID, uint256 _votes) external payable {
		require(block.timestamp < endTime);
		Project storage project = _projects[_projectID];

		uint256 cost = _votingCost(msg.sender, project, _votes);

		if (_isERC20Round()) {
			IERC20 acceptToken = IERC20(_acceptToken);
			require(acceptToken.transferFrom(msg.sender, address(this), cost));
		} else {
			require(msg.value >= cost);
			uint256 rest = msg.value - cost;
			if (rest > 0) {
				_tax = _tax.add(rest);
			}
		}

		uint256 fee = cost.mul(TAX_POINT) / 10000;
		uint256 grants = cost - fee;
		_tax += fee;

		project.votes[msg.sender] += _votes;
		project.grants += grants;
		_votesRecord[_projectID][msg.sender] += grants;
		uint256 supportArea = _votes.mul(project.totalVotes - voted);

		if (votingPower > 10000) {
			(bool authenticated, uint256 stakingAmount, uint256 stakingEndTime) = DORA_ID.statusOf(msg.sender);
			if (authenticated && stakingAmount > 10 ether && stakingEndTime >= endTime) {
				supportArea = supportArea.mul(votingPower) / 10000;
			}
		}

		project.totalVotes += _votes;
		project.supportArea = supportArea.add(project.supportArea);
		if (!ban[_projectID]) {
			_totalSupportArea = supportArea.add(_totalSupportArea);
		}

		emit Vote(msg.sender, _projectID, _votes);
	}

	function takeOutGrants(uint256 _projectID, uint256 _amount) external {
		require(address(bytes20(bytes32(_projectID))) == msg.sender);
		Project storage project = _projects[_projectID];
		(uint256 rest, ) = grantsOf(_projectID);
		require(rest >= _amount);

		project.withdrew += _amount;

		if (_isERC20Round()) {
			IERC20 acceptToken = IERC20(_acceptToken);
			require(acceptToken.transfer(msg.sender, _amount));
		} else {
			payable(msg.sender).transfer(_amount);
		}
	}

	function withdraw() external onlyOwner {
		uint256 amount = _tax;
		_tax = 0;

		if (_isERC20Round()) {
			IERC20 acceptToken = IERC20(_acceptToken);
			require(acceptToken.transfer(owner, amount));
		} else {
			owner.transfer(amount);
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
		donate.value(msg.value)(msg.value);
	}
}
