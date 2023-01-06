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
        mapping(address => uint256) whitelistVoter;
    }

    struct Project {
        ProjectStatus status;
        uint256 categoryIdx;
        uint256 participationRoundIdx; // ! useless
        uint256 validRound;
        uint256 voters;
    }

    uint256 internal constant UNIT = 1000000;
    // uint256 internal constant TAX_THRESHOLD = 5000 * UNIT; // ! useless
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
    // distribution ratio
    uint256 internal R;

    // input: decimals 18
    // output: decimals 1
    function log2(uint256 n) public pure returns (uint256) {
        n = ((n + 2e18) * 256) / 1e18;
        uint256 d = 0;
        while (n > 50859008) {
            n = n / 256;
            d += 80;
        }
        uint256 n2 = n * n;
        uint256 n4 = n2 * n2;
        uint256 x = n4 * n4 * n2;
        uint256 y;
        assembly {
            let arg := x
            x := sub(x, 1)
            x := or(x, div(x, 0x02))
            x := or(x, div(x, 0x04))
            x := or(x, div(x, 0x10))
            x := or(x, div(x, 0x100))
            x := or(x, div(x, 0x10000))
            x := or(x, div(x, 0x100000000))
            x := or(x, div(x, 0x10000000000000000))
            x := or(x, div(x, 0x100000000000000000000000000000000))
            x := add(x, 1)
            let m := mload(0x40)
            mstore(
                m,
                0xf8f9cbfae6cc78fbefe7cdc3a1793dfcf4f0e8bbd8cec470b6a28a7a5a3e1efd
            )
            mstore(
                add(m, 0x20),
                0xf5ecf1b3e9debc68e1d9cfabc5997135bfb7a7a3938b7b606b5b4b3f2f1f0ffe
            )
            mstore(
                add(m, 0x40),
                0xf6e4ed9ff2d6b458eadcdf97bd91692de2d4da8fd2d0ac50c6ae9a8272523616
            )
            mstore(
                add(m, 0x60),
                0xc8c0b887b0a8a4489c948c7f847c6125746c645c544c444038302820181008ff
            )
            mstore(
                add(m, 0x80),
                0xf7cae577eec2a03cf3bad76fb589591debb2dd67e0aa9834bea6925f6a4a2e0e
            )
            mstore(
                add(m, 0xa0),
                0xe39ed557db96902cd38ed14fad815115c786af479b7e83247363534337271707
            )
            mstore(
                add(m, 0xc0),
                0xc976c13bb96e881cb166a933a55e490d9d56952b8d4e801485467d2362422606
            )
            mstore(
                add(m, 0xe0),
                0x753a6d1b65325d0c552a4d1345224105391a310b29122104190a110309020100
            )
            mstore(0x40, add(m, 0x100))
            let
                magic
            := 0x818283848586878898a8b8c8d8e8f929395969799a9b9d9e9faaeb6bedeeff
            let
                shift
            := 0x100000000000000000000000000000000000000000000000000000000000000
            let a := div(mul(x, magic), shift)
            y := div(mload(add(m, sub(255, a))), shift)
            y := add(
                y,
                mul(
                    256,
                    gt(
                        arg,
                        0x8000000000000000000000000000000000000000000000000000000000000000
                    )
                )
            )
        }

        return y - 80 + d;
    }

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
            uint256[] memory totalArea,
            uint256[] memory topVotes,
            uint256[] memory minVotes,
            uint256[] memory projectNumber
        )
    {
        Round storage round = _rounds[_r];
        startAt = round.startAt;
        endAt = round.endAt;
        category = round.category;

        uint256 l = category.length;
        matchingPool = new uint256[](l);
        totalArea = new uint256[](l);
        topVotes = new uint256[](l);
        minVotes = new uint256[](l);
        projectNumber = new uint256[](l);
        for (uint256 i = 0; i < category.length; i++) {
            uint256 c = category[i];
            matchingPool[i] = round.matchingPoolCategorial[c];
            totalArea[i] = round.totalVotesCategorial[c];

            Category storage categoryInfo = round.categoryInfo[c];
            topVotes[i] = categoryInfo.topVotes;
            minVotes[i] = categoryInfo.minVotes;
            projectNumber[i] = categoryInfo.projectNumber;
        }
    }
}
