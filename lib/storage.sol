// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

abstract contract GrantStorage {
    enum ProjectStatus {
        Empty,
        Normal,
        Banned
    }

    struct Category {
        uint256 topVotes;
        uint256 minVotes; // min (but not zero) votes number
        uint256 minVotesProject;
        uint256 projectNumber;
    }

    struct Round {
        uint256 startAt;
        uint256 endAt;
        uint256 votePrice;
        mapping(uint256 => uint256) voters;
        mapping(uint256 => uint256) votes;
        mapping(uint256 => uint256) contribution;
        mapping(uint256 => uint256) areas; // now, it's used as votes * UNIT
        mapping(uint256 => bool) withdrew;
        mapping(uint256 => mapping(address => uint256)) voted;
        mapping(uint256 => bool) hasCategory;
        uint256[] category;
        mapping(uint256 => uint256) matchingPoolCategorial;
        mapping(uint256 => uint256) totalVotesCategorial;
        // VERSION 2.0 change: topVotesCategorial => categoryInfo
        mapping(uint256 => Category) categoryInfo;
        // VERSION 2.0 add
        address roundSinger;
        mapping(uint256 => bool) validProjects;
        mapping(address => bool) whitelistVoter;
    }

    struct Project {
        ProjectStatus status;
        uint256 categoryIdx;
        uint256 participationRoundIdx; // ! useless
        uint256 validRound;
        uint256 voters;
    }

    uint256 internal constant UNIT = 1000000;
    uint256 internal constant TAX_THRESHOLD = 5000 * UNIT; // ! useless
    uint256 public TAX_POINT;

    address payable public owner;

    uint256 public currentRound;

    mapping(uint256 => Project) internal _projects;
    // project => user => contribution
    mapping(uint256 => mapping(address => uint256)) internal _totalContribution;
    mapping(uint256 => Round) internal _rounds;
    uint256[] internal _projectList;
    uint256 internal _tax;

    bool public initialized;
    bool internal _rentrancyLock;

    // VERSION 2.0 add
    uint256 internal R;

    function projectOf(uint256 _p) external view returns (Project memory) {
        return _projects[_p];
    }

    function rankingList(uint256 _r)
        external
        view
        returns (
            uint256[] memory projects,
            uint256[] memory category,
            uint256[] memory voters,
            uint256[] memory votes,
            uint256[] memory areas,
            uint256[] memory contribution
        )
    {
        return rankingListPaged(_r, 0, 1000);
    }

    function rankingListPaged(
        uint256 _r,
        uint256 _page,
        uint256 _size
    )
        public
        view
        returns (
            uint256[] memory projects,
            uint256[] memory category,
            uint256[] memory voters,
            uint256[] memory votes,
            uint256[] memory areas,
            uint256[] memory contribution
        )
    {
        Round storage round = _rounds[_r];
        uint256 start = _page * _size;
        if (start < _projectList.length) {
            uint256 l = _size;
            if (start + _size > _projectList.length) {
                l = _projectList.length - start;
            }
            projects = new uint256[](l);
            category = new uint256[](l);
            voters = new uint256[](l);
            votes = new uint256[](l);
            areas = new uint256[](l);
            contribution = new uint256[](l);
            for (uint256 i = 0; i < l; i++) {
                uint256 pid = _projectList[start + i];
                projects[i] = pid;
                category[i] = _projects[pid].categoryIdx;
                voters[i] = round.voters[pid];
                votes[i] = round.votes[pid];
                areas[i] = round.areas[pid];
                contribution[i] = round.contribution[pid];
            }
        }
    }

    function roundInfo(uint256 _r)
        external
        view
        returns (
            uint256 startAt,
            uint256 endAt,
            uint256[] memory category,
            uint256[] memory matchingPool,
            uint256[] memory totalArea
        )
    {
        Round storage round = _rounds[_r];
        startAt = round.startAt;
        endAt = round.endAt;
        category = round.category;

        matchingPool = new uint256[](category.length);
        totalArea = new uint256[](category.length);
        for (uint256 i = 0; i < category.length; i++) {
            matchingPool[i] = round.matchingPoolCategorial[category[i]];
            totalArea[i] = round.totalVotesCategorial[category[i]];
        }
    }
}
