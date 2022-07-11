// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import {GrantStorage} from "./lib/storage.sol";
import {GrantAdmin} from "./lib/admin.sol";
import {GrantUser} from "./lib/user.sol";

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

    function initialize(address payable _owner) external {
        require(!initialized);
        require(_owner != address(0));
        initialized = true;

        owner = _owner;
        currentRound = 1;
        TAX_POINT = 50000;
    }

    function ongoing() public view returns (bool) {
        Round storage round = _rounds[currentRound];
        return
            round.startAt <= block.timestamp && round.endAt > block.timestamp;
    }

    function votingCost(
        address _from,
        uint256 _p,
        uint256 _votes
    ) public view returns (uint256 cost, bool votable) {
        require(_votes < 1 ether);

        Round storage round = _rounds[currentRound];
        Project storage project = _projects[_p];

        votable =
            project.status == ProjectStatus.Normal &&
            // project.participationRoundIdx >= currentRound &&
            round.validProjects[_p] &&
            ongoing();

        uint256 voted = round.voted[_p][_from];
        uint256 votingPoints = (_votes * (_votes + 1)) / 2;
        votingPoints += _votes * voted;
        cost = votingPoints * round.votePrice;
    }

    function grantsOf(uint256 _r, uint256 _p) public view returns (uint256) {
        if (_r >= currentRound) return 0;

        Round storage round = _rounds[_r];
        Project storage project = _projects[_p];

        if (round.withdrew[_p]) return 0;
        if (project.validRound > _r) return 0; // project category change

        uint256 category = project.categoryIdx;
        if (!round.hasCategory[category]) {
            category = 0;
        }

        uint256 total = round.contribution[_p];

        uint256 totalVotes = round.totalVotesCategorial[category];
        uint256 votes = round.areas[_p];

        if (_r > 1 && votes > 0) {
            // only from round 2
            Category storage categoryInfo = round.categoryInfo[category];

            uint256 a = totalVotes / categoryInfo.projectNumber; // averageVotes
            uint256 t = categoryInfo.topVotes; // topVotes
            uint256 m = categoryInfo.minVotes; // minVotes

            // The number of final results of the first place is R times that of the last place.
            // => a + s(t - a) = (a - s(a - m)) * R
            // => s(t - a + (a - m) * R) = aR - a
            // => s = a(R - 1) / (t - a + (a - m) * R)
            uint256 d = t - a + (a - m) * R;
            if (d > 0) {
                uint256 s = (a * (R - 1) * UNIT) / d;
                if (s < UNIT) {
                    if (votes > a) {
                        votes = a + ((votes - a) * s) / UNIT;
                    } else {
                        votes = votes + ((a - votes) * (UNIT - s)) / UNIT;
                    }
                }
            }
        }

        if (totalVotes != 0) {
            total +=
                (votes * round.matchingPoolCategorial[category]) /
                totalVotes;
        }
        return total;
    }

    function donate(uint256 _amount, uint256 _category)
        public
        payable
        nonReentrant
    {
        require(_amount == msg.value);

        Round storage round = _rounds[currentRound];
        require(round.hasCategory[_category] || _category == 0);

        uint256 tax = (_amount * TAX_POINT) / UNIT;

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

    function vote(
        uint256 _p,
        uint256 _votes,
        bytes calldata _sign
    ) external payable {
        if (_sign.length == 65) {
            // proof of white list
            Round storage round = _rounds[currentRound];
            bytes32 h = keccak256(
                abi.encodePacked(address(this), currentRound, msg.sender)
            );
            uint8 v = uint8(bytes1(_sign[64:]));
            (bytes32 r, bytes32 s) = abi.decode(_sign[:64], (bytes32, bytes32));
            address signer = ecrecover(h, v, r, s);
            if (signer == round.roundSinger) {
                round.whitelistVoter[msg.sender] = true;
            }
        }
        vote(_p, _votes);
    }

    function vote(uint256 _p, uint256 _votes) public payable nonReentrant {
        require(_votes > 0);

        Round storage round = _rounds[currentRound];
        require(round.whitelistVoter[msg.sender]);

        (uint256 cost, bool votable) = votingCost(msg.sender, _p, _votes);
        require(votable);
        require(msg.value >= cost);

        uint256 projectContribution = _totalContribution[_p][msg.sender];
        _totalContribution[_p][msg.sender] = projectContribution + cost;
        if (projectContribution == 0) {
            _projects[_p].voters++;
        }

        uint256 rest = msg.value - cost;
        if (rest > 0) {
            _tax = _tax + rest;
        }

        uint256 fee = (cost * TAX_POINT) / UNIT;
        uint256 contribution = cost - fee;
        _tax += fee;

        round.contribution[_p] += contribution;

        _processVoteAndArea(round, _p, msg.sender, _votes);

        emit Vote(msg.sender, _p, _votes);
    }

    function _processVoteAndArea(
        Round storage round,
        uint256 _p,
        address _from,
        uint256 _votes
    ) internal {
        uint256 category = _projects[_p].categoryIdx;
        if (!round.hasCategory[category]) {
            category = 0;
        }

        Category storage categoryInfo = round.categoryInfo[category];

        if (round.voted[_p][_from] == 0) {
            round.voters[_p]++;
        }
        round.voted[_p][_from] += _votes;
        round.votes[_p] += _votes;

        if (round.areas[_p] == 0) {
            categoryInfo.projectNumber++;
        }
        uint256 incArea = _votes * UNIT;
        uint256 newArea = round.areas[_p] + incArea;
        round.areas[_p] = newArea;

        round.totalVotesCategorial[category] += incArea;
        if (newArea > categoryInfo.topVotes) {
            categoryInfo.topVotes = newArea;
        }
        uint256 minVotesProject = categoryInfo.minVotesProject;
        if (minVotesProject == 0 || newArea < categoryInfo.minVotes) {
            categoryInfo.minVotes = newArea;
            categoryInfo.minVotesProject = _p;
        } else if (minVotesProject == _p) {
            categoryInfo.minVotes = newArea;
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
*/

    receive() external payable {
        donate(msg.value, 0);
    }
}
