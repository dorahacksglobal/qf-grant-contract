// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

contract Grant {
    
    address payable public owner;
	uint256 public taxPoint = 100; // * 1/10000
	uint256 private _tax;

    uint256 public currentRound = 1;
    mapping(uint256 => uint256) public startTime;
    mapping(uint256 => uint256) public endTime;
    mapping(uint256 => uint256) public votingUnit;

    uint256 public interval = 60 days;
    uint256 public basicVotingUnit = 1e17;
    
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
    
    constructor() {
        owner = msg.sender;
    }
    
    function allProjects(uint256 _round) public view returns (uint256[] memory projects) {
        projects = _projectList[_round];
    }
    
    function rankingList(uint256 _round) public view returns (
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
            votes[i] = _projects[projects[i]].totalVotes;
            support[i] = _projects[projects[i]].supportArea;
            grants[i] = _projects[projects[i]].grants;
        }
    }
    
    function roundInfo(uint256 _round) public view returns (
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
    
    function votingCost(address _from, uint256 _projectID, uint256 _votes) public view returns (uint256 cost, bool votable) {
        Project storage project = _projects[_projectID];
        votable = project.round == currentRound && block.timestamp < endTime[currentRound];

        uint256 voted = project.votes[_from];
        uint256 votingPoints = (1 + _votes) * _votes / 2;
        votingPoints += voted * _votes;
        cost = votingPoints * votingUnit[project.round];
    }
    
    function grantsOf(uint256 _projectID) public view returns (uint256 rest, uint256 total) {
        Project storage project = _projects[_projectID];
        uint256 pRound = project.round;
        if (pRound == 0) {						// empty project
            return (0, 0);
        } else if (pRound < currentRound) {		// round end
            total = project.grants + project.supportArea * supportPool[pRound] / _totalSupportArea[pRound];
        } else {								// continuous voting ...
            total = project.grants;
        }
        rest = total - project.withdrew;
    }
    
    function projectOf(uint256 _projectID) public view returns (
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
        supportArea = project.supportArea;
        withdrew = project.withdrew;
    }
    
    function roundOver() public {
        require(block.timestamp > endTime[currentRound]);
        currentRound++;
    }
    
    function setTaxPoint(uint256 _taxPoint) public {
        require(msg.sender == owner);
        require(_taxPoint <= 5000);
        taxPoint = _taxPoint;
    }
    
    function setInterval(uint256 _interval) public {
        require(msg.sender == owner);
        interval = _interval;
    }
    
    function setVotingUnit(uint256 _unit) public {
        require(msg.sender == owner);
        basicVotingUnit = _unit;
    }
    
    function roundStart() public {
        require(msg.sender == owner);
        require(endTime[currentRound] == 0);
        votingUnit[currentRound] = basicVotingUnit;
        startTime[currentRound] = block.timestamp;
        endTime[currentRound] = block.timestamp + interval;
    }
    
    function donate() public payable {
		uint256 fee = msg.value / 10000 * taxPoint;
		uint256 support = msg.value - fee;
		_tax += fee;
        supportPool[currentRound] += support;
		preTaxSupportPool[currentRound] += msg.value;
    }
    
    function uploadProject(uint256 _projectID) public {
        require(block.timestamp < endTime[currentRound]);
        require(address(_projectID) == msg.sender);
        Project storage project = _projects[_projectID];
        require(project.createAt == 0);
        project.round = currentRound;
        project.createAt = block.timestamp;
        _projectList[currentRound].push(_projectID);
    }
    
    function vote(uint256 _projectID, uint256 _votes) public payable {
        require(block.timestamp < endTime[currentRound]);
        Project storage project = _projects[_projectID];
        require(project.round == currentRound);

        uint256 voted = project.votes[msg.sender];
        uint256 votingPoints = (1 + _votes) * _votes / 2;
        votingPoints += voted * _votes;
        uint256 cost = votingPoints * votingUnit[currentRound];
        
        require(msg.value >= cost);

		uint256 fee = cost / 10000 * taxPoint;
		uint256 grants = cost - fee;
		_tax += fee;

        project.votes[msg.sender] += _votes;
        project.grants += grants;
        uint256 supportArea = (project.totalVotes - voted) * _votes;
        project.totalVotes += _votes;
        project.supportArea += supportArea;
        _totalSupportArea[currentRound] += supportArea;

		uint256 rest = msg.value - cost;
		if (rest > 0) {
			msg.sender.transfer(rest);
		}
    }
    
    function takeOutGrants(uint256 _projectID, uint256 _amount) public {
        require(address(_projectID) == msg.sender);
        Project storage project = _projects[_projectID];
        (uint256 rest, ) = grantsOf(_projectID);
        require(rest >= _amount);
        project.withdrew += _amount;
        msg.sender.transfer(_amount);
    }

	function withdraw() public {
		require(msg.sender == owner);
		uint256 amount = _tax;
		_tax = 0;
		owner.transfer(amount);
	}

	receive() external payable {
		donate();
	}
}