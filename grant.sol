// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import {IERC20} from "./interface/IERC20.sol";
import {GrantFactory} from "./GrantFactory.sol";

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

    uint256 private constant UNIT = 1000000;

    bool public initialized;

    address payable public owner;
    GrantFactory public factory;

    uint256 public currentRound = 0;
    uint256 public startTime;
    uint256 public endTime;

    address private _acceptToken;

    uint256 public basicVotingUnit;

    uint256 private _tax;

    struct Project {
        uint256 round;
        uint256 createAt;
        uint256 voters;
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

    uint256 private _topArea;
    uint256 private _minArea;
    uint256 private _minAreaProject;
    uint256 private _projectNumber;

    // mapping(uint256 => bool) public ban;
    mapping(uint256 => mapping(address => uint256)) private _votesRecord;

    bool public roundEnd;

    bool private _rentrancyLock;

    // v2.1
    uint256 public TAX_POINT;

    uint256 public votingTime;

    // VERSION 3.0 add
    // distribution ratio
    uint256 private R;

    function initialize(
        GrantFactory _factory,
        address payable _owner,
        uint256 _start,
        uint256 _end,
        address _token,
        uint256 _votingUnit
    ) external {
        require(!initialized);
        require(_owner != address(0));
        initialized = true;

        factory = _factory;
        owner = _owner;
        startTime = _start;
        endTime = _end;
        _acceptToken = _token;
        basicVotingUnit = _votingUnit;
        TAX_POINT = 50000;
        R = 20;
    }

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

    function allProjects(uint256)
        external
        view
        returns (uint256[] memory projects)
    {
        return _projectList;
    }

    function rankingList(uint256)
        external
        view
        returns (
            uint256[] memory projects,
            uint256[] memory voters,
            uint256[] memory votes,
            uint256[] memory area,
            uint256[] memory grants
        )
    {
        projects = _projectList;
        voters = new uint256[](projects.length);
        votes = new uint256[](projects.length);
        support = new uint256[](projects.length);
        grants = new uint256[](projects.length);
        for (uint256 i = 0; i < projects.length; i++) {
            uint256 pid = projects[i];
            voters[i] = _projects[pid].voters;
            votes[i] = _projects[pid].totalVotes;
            support[i] = _projects[pid].supportArea;
            grants[i] = _projects[pid].grants;
        }
    }

    function roundInfo(uint256) external view returns (uint256[8]) {
        return [
            startTime,
            endTime,
            supportPool,
            preTaxSupportPool,
            _totalSupportArea,
            _topArea,
            _minArea,
            _projectNumber
        ];
    }

    function acceptTokenInfo()
        external
        view
        returns (
            address token,
            string memory symbol,
            uint256 decimals
        )
    {
        require(_isERC20Round());

        IERC20 acceptToken = IERC20(_acceptToken);
        token = address(acceptToken);
        symbol = acceptToken.symbol();
        decimals = acceptToken.decimals();
    }

    function votingCost(
        address _from,
        uint256 _projectID,
        uint256 _votes
    ) external view returns (uint256 cost, bool votable) {
        Project storage project = _projects[_projectID];
        votable = project.round == currentRound && block.timestamp < endTime;
        cost = _votingCost(_from, project, _votes);
    }

    function grantsOf(uint256 _projectID)
        public
        view
        returns (uint256 rest, uint256 total)
    {
        Project storage project = _projects[_projectID];
        if (!roundEnd) {
            return (0, 0);
        }
        total = project.grants;

        uint256 area = project.supportArea;
        if (area > 0) {
            uint256 a = _totalSupportArea / _projectNumber; // averageVotes
            uint256 t = _topArea;
            uint256 m = _minArea;

            // The number of final results of the first place is R times that of the last place.
            // => a + s(t - a) = (a - s(a - m)) * R
            // => s(t - a + (a - m) * R) = aR - a
            // => s = a(R - 1) / (t - a + (a - m) * R)
            uint256 d = t - a + (a - m) * R;
            if (d > 0) {
                uint256 s = (a * (R - 1) * UNIT) / d;
                if (s < UNIT) {
                    if (area > a) {
                        area = a + ((area - a) * s) / UNIT;
                    } else {
                        area = area + ((a - area) * (UNIT - s)) / UNIT;
                    }
                }
            }
        }

        if (_totalSupportArea != 0) {
            total = total.add(area.mul(supportPool) / _totalSupportArea);
        }

        require(total >= project.withdrew);
        rest = total - project.withdrew;
    }

    function projectOf(uint256 _projectID)
        external
        view
        returns (Project memory)
    {
        return _projects[_projectID];
    }

    function votesOf(uint256 _projectID, address _user)
        external
        view
        returns (uint256)
    {
        return _votesRecord[_projectID][_user];
    }

    function setTime(uint256 _start, uint256 _end) external onlyOwner {
        require(!roundEnd);
        require(_start < _end);

        startTime = _start;
        endTime = _end;
    }

    function setVotingTime(uint256 _ts) external onlyOwner {
        votingTime = _ts;
    }

    function setTexPoint(uint256 _taxPoint) external onlyOwner {
        TAX_POINT = _taxPoint;
    }

    function roundOver() external onlyOwner {
        require(block.timestamp > endTime && endTime > 0);
        roundEnd = true;
    }

    function changeOwner(address payable _newOwner) external onlyOwner {
        require(_newOwner != address(0));
        owner = _newOwner;
    }

    function donate(uint256 _amount) public payable nonReentrant {
        require(!roundEnd);

        if (_isERC20Round()) {
            IERC20 acceptToken = IERC20(_acceptToken);
            require(
                acceptToken.transferFrom(msg.sender, address(this), _amount)
            );
        } else {
            require(_amount == msg.value);
        }

        uint256 fee = _amount.mul(TAX_POINT) / UNIT;
        uint256 support = _amount - fee;
        _tax += fee;
        supportPool += support;
        preTaxSupportPool += _amount;
    }

    function uploadProject(uint256 _projectID) external {
        require(block.timestamp > startTime);
        require(block.timestamp < endTime);
        require(address(uint160(_projectID)) == msg.sender);
        Project storage project = _projects[_projectID];
        require(project.createAt == 0);
        project.round = currentRound;
        project.createAt = block.timestamp;
        _projectList.push(_projectID);
    }

    function vote(uint256 _projectID, uint256 _votes)
        external
        payable
        nonReentrant
    {
        require(votingTime == 0 || block.timestamp >= votingTime);
        require(block.timestamp < endTime);
        require(_votes > 0);
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

        uint256 fee = cost.mul(TAX_POINT) / UNIT;
        uint256 grants = cost - fee;
        _tax += fee;

        project.grants += grants;

        _processVoteAndArea(_projectID, msg.sender, _votes);

        emit Vote(msg.sender, _projectID, _votes);
    }

    function _processVoteAndArea(
        uint256 _projectID,
        address sender,
        uint256 _votes
    ) internal {
        Project storage project = _projects[_projectID];
        uint256 voted = _votesRecord[_projectID][sender];
        if (voted == 0) {
            project.voters++;
        }
        _votesRecord[_projectID][sender] += _votes;

        uint256 incArea = _votes.mul(project.totalVotes - voted).mul(UNIT);

        project.totalVotes += _votes;
        uint256 newArea = project.supportArea + incArea;

        if (project.supportArea == 0 && incArea != 0) {
            _projectNumber++;
        }
        project.supportArea = newArea;
        _totalSupportArea += newArea;

        if (project.supportArea > _topArea) {
            _topArea = project.supportArea;
        }
        if (_minAreaProject == 0 || newArea < _minArea) {
            _minArea = newArea;
            _minAreaProject = _p;
        } else if (_minAreaProject == _p) {
            _minArea = newArea;
        }
    }

    function takeOutGrants(uint256 _projectID, uint256 _amount)
        external
        nonReentrant
    {
        require(address(uint160(_projectID)) == msg.sender);
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

    function withdraw() external nonReentrant onlyOwner {
        uint256 amount = _tax;
        _tax = 0;

        if (_isERC20Round()) {
            IERC20 acceptToken = IERC20(_acceptToken);
            require(acceptToken.transfer(owner, amount));
        } else {
            owner.transfer(amount);
        }
    }

    function _votingCost(
        address _from,
        Project storage project,
        uint256 _votes
    ) internal view returns (uint256 cost) {
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
