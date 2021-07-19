// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import { IERC20 } from "./interface/IERC20.sol";

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

// Based on ManageableGrantV2.sol

contract Grant {
	using SafeMath for uint256;

	bool initialized;

	address payable public owner;
	uint256 public taxPoint; // * 1/10000
	uint256 private _tax;

	uint256 public currentRound;
	mapping(uint256 => uint256) public startTime;
	mapping(uint256 => uint256) public endTime;
	mapping(uint256 => uint256) public votingUnit;

	uint256 public interval;
	uint256 public basicVotingUnit;

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
	mapping(uint256 => uint256[]) private _projectList;

	mapping(uint256 => uint256) public supportPool;
	mapping(uint256 => uint256) public preTaxSupportPool;
	mapping(uint256 => uint256) private _totalSupportArea;

	mapping(uint256 => bool) public ban;

	IERC20 public acceptToken;

	mapping(uint256 => mapping(address => uint256)) private _votesRecord;

	constructor(IERC20 _acceptToken) {
		initialize(_acceptToken);
	}

	function initialize (IERC20 _acceptToken) public {
		require(!initialized);
		initialized = true;
		taxPoint = 500;
		currentRound = 1;
		interval = 60 days;
		basicVotingUnit = 1e18;
		owner = msg.sender;
	
		acceptToken = _acceptToken;
	}

	event BanProject(uint256 indexed project, bool ban);
	event TaxPointChange(uint256 taxPoint);
	event RoundIntervalChange(uint256 interval);
	event VotingUnitChange(uint256 votingUnit);

	// Add event
	event Vote(address indexed account, uint256 indexed project, uint256 vote);
	 
	modifier onlyOwner() {
		require(msg.sender == owner);
		_;
	}

	function acceptTokenInfo() external view returns (
		address token,
		string memory symbol,
		uint256 decimals
	) {
		token = address(acceptToken);
		symbol = acceptToken.symbol();
		decimals = acceptToken.decimals();
	}

	function allProjects(uint256 _round) external view returns (uint256[] memory projects) {
		projects = _projectList[_round];
	}

	function rankingList(uint256 _round) external view returns (
		uint256 unit,
		uint256[] memory projects,
		uint256[] memory votes,
		uint256[] memory support,
		uint256[] memory grants
	) {
		if (_totalSupportArea[_round] != 0) {
			unit = supportPool[_round] / _totalSupportArea[_round];
		}
		projects = _projectList[_round];
		votes = new uint256[](projects.length);
		support = new uint256[](projects.length);
		grants = new uint256[](projects.length);
		for (uint256 i = 0; i < projects.length; i++) {
			uint256 pid = projects[i];
			votes[i] = _projects[pid].totalVotes;
			support[i] = ban[pid] ? 0 : _projects[pid].supportArea;
			grants[i] = _projects[pid].grants;
		}
	}

	function rankingListPaged(uint256 _round, uint256 _page, uint256 _size) external view returns (
		uint256 unit,
		uint256[] memory projects,
		uint256[] memory votes,
		uint256[] memory support,
		uint256[] memory grants
	) {
		if (_totalSupportArea[_round] != 0) {
			unit = supportPool[_round] / _totalSupportArea[_round];
		}
		uint256[] storage fullProjects = _projectList[_round];
		uint256 start = _page * _size;
		uint256 end = start + _size;
		projects = new uint256[](_size);
		votes = new uint256[](_size);
		support = new uint256[](_size);
		grants = new uint256[](_size);
		if (end > projects.length) {
			end = projects.length;
		}
		for (uint256 i = start; i < end; i++) {
			if (i >= fullProjects.length) {
				break;
			}
			uint256 pid = fullProjects[i];
			projects[i] = pid;
			votes[i] = _projects[pid].totalVotes;
			support[i] = ban[pid] ? 0 : _projects[pid].supportArea;
			grants[i] = _projects[pid].grants;
		}
	}

	function roundInfo(uint256 _round) external view returns (
		uint256 startFrom,
		uint256 endAt,
		uint256 support,
		uint256 preTaxSupport
	) {
		startFrom = startTime[_round];
		endAt = endTime[_round];
		support = supportPool[_round];
		preTaxSupport = preTaxSupportPool[_round];
	}

	function votingCost(address _from, uint256 _projectID, uint256 _votes) external view returns (uint256 cost, bool votable) {
		Project storage project = _projects[_projectID];
		votable = project.round == currentRound && block.timestamp < endTime[currentRound];

		uint256 voted = project.votes[_from];
		uint256 votingPoints = _votes.mul(_votes.add(1)) / 2;
		votingPoints = votingPoints.add(_votes.mul(voted));
		cost = votingPoints.mul(votingUnit[project.round]);
	}

	// Fixed:
	// Developers cannot now take any of their own bonuses before the end of the round,
	// preventing them from using them again for repeated voting.
	function grantsOf(uint256 _projectID) public view returns (uint256 rest, uint256 total) {
		Project storage project = _projects[_projectID];
		uint256 pRound = project.round;
		if (pRound == currentRound) {
			return (0, 0);
		}
		total = project.grants; // round end
		if (_totalSupportArea[pRound] != 0 && !ban[_projectID]) {
			total = total.add(project.supportArea.mul(supportPool[pRound]) / _totalSupportArea[pRound]);
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
		grants = project.grants;
		supportArea = ban[_projectID] ? 0 : project.supportArea;
		withdrew = project.withdrew;
	}

	function votesOf(uint256 _projectID, address _user) external view returns (uint256) {
		return _votesRecord[_projectID][_user];
	}

	// Added:
	function dangerSetTime(uint256 _start, uint256 _end) external onlyOwner {
		startTime[currentRound] = _start;
		endTime[currentRound] = _end;
	}

	function roundOver() external onlyOwner {
		require(block.timestamp > endTime[currentRound] && endTime[currentRound] > 0);
		currentRound++;
	}

	function changeOwner(address payable _newOwner) external onlyOwner {
		owner = _newOwner;
	}

	function banProject(uint256 _projectID, bool _ban) external onlyOwner {
		Project storage project = _projects[_projectID];
		require(project.round == currentRound);
		require(ban[_projectID] != _ban);
		ban[_projectID] = _ban;
		if (_ban) {
			_totalSupportArea[currentRound] -= project.supportArea;
		} else {
			_totalSupportArea[currentRound] = project.supportArea.add(_totalSupportArea[currentRound]);
		}
		emit BanProject(_projectID, _ban);
	}

	function setTaxPoint(uint256 _taxPoint) external onlyOwner {
		require(_taxPoint <= 5000);
		taxPoint = _taxPoint;
		emit TaxPointChange(_taxPoint);
	}

	function setInterval(uint256 _interval) external onlyOwner {
		interval = _interval;
		emit RoundIntervalChange(_interval);
	}

	function setVotingUnit(uint256 _unit) external onlyOwner {
		basicVotingUnit = _unit;
		emit VotingUnitChange(_unit);
	}

	function roundStart() external onlyOwner {
		require(endTime[currentRound] == 0);
		votingUnit[currentRound] = basicVotingUnit;
		startTime[currentRound] = block.timestamp;
		endTime[currentRound] = block.timestamp + interval;
	}

	function roundStartAt(uint256 _start, uint256 _end) external onlyOwner {
		require(endTime[currentRound] == 0);
		votingUnit[currentRound] = basicVotingUnit;
		startTime[currentRound] = _start;
		endTime[currentRound] = _end;
	}

	function donateToken(uint256 _amount) public {
		require(acceptToken.transferFrom(msg.sender, address(this), _amount));
		uint256 fee = _amount.mul(taxPoint) / 10000;
		uint256 support = _amount - fee;
		_tax += fee;
		supportPool[currentRound] += support;
		preTaxSupportPool[currentRound] += _amount;
	}

	function uploadProject(uint256 _projectID) external {
		require(block.timestamp > startTime[currentRound]);
		require(block.timestamp < endTime[currentRound]);
		require(address(_projectID) == msg.sender);
		Project storage project = _projects[_projectID];
		require(project.createAt == 0);
		project.round = currentRound;
		project.createAt = block.timestamp;
		_projectList[currentRound].push(_projectID);
	}

	function vote(uint256 _projectID, uint256 _votes) external {
		require(block.timestamp < endTime[currentRound]);
		Project storage project = _projects[_projectID];
		require(project.round == currentRound);

		uint256 voted = project.votes[msg.sender];
		uint256 votingPoints = _votes.mul(_votes.add(1)) / 2;
		votingPoints = votingPoints.add(_votes.mul(voted));
		uint256 cost = votingPoints.mul(votingUnit[currentRound]);

		require(acceptToken.transferFrom(msg.sender, address(this), cost));

		uint256 fee = cost.mul(taxPoint) / 10000;
		uint256 grants = cost - fee;
		_tax += fee;

		project.votes[msg.sender] += _votes;
		project.grants += grants;
		_votesRecord[_projectID][msg.sender] += grants;
		uint256 supportArea = _votes.mul(project.totalVotes - voted);
		project.totalVotes += _votes;
		project.supportArea = supportArea.add(project.supportArea);
		if (!ban[_projectID]) {
			_totalSupportArea[currentRound] = supportArea.add(_totalSupportArea[currentRound]);
		}

		emit Vote(msg.sender, _projectID, _votes);
	}

	function takeOutGrants(uint256 _projectID, uint256 _amount) external {
		require(address(_projectID) == msg.sender);
		Project storage project = _projects[_projectID];
		(uint256 rest, ) = grantsOf(_projectID);
		require(rest >= _amount);
		project.withdrew += _amount;
		require(acceptToken.transfer(msg.sender, _amount));
	}

	function withdraw() external onlyOwner {
		uint256 amount = _tax;
		_tax = 0;
		require(acceptToken.transfer(owner, amount));
	}
}