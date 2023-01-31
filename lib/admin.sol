// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import {GrantStorage} from "./storage.sol";

contract GrantAdmin is GrantStorage {
    event BanProject(uint256 indexed project, bool banned);
    event AdjustProjectArea(
        uint256 indexed round,
        uint256 indexed project,
        uint256 area,
        string reason
    );
    event AdjustCategory(
        uint256 indexed round,
        uint256 indexed project,
        uint256 category
    );

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function changeOwner(address payable _newOwner) external onlyOwner {
        require(_newOwner != address(0));
        owner = _newOwner;
    }

    function setDistributionRatio(uint256 _r) external onlyOwner {
        R = _r;
    }

    function roundStart(
        uint256 _startAt,
        uint256 _endAt,
        uint256 _votePrice,
        address _signer,
        uint256[] memory _category
    ) external onlyOwner {
        Round storage round = _rounds[currentRound];
        require(round.startAt == 0);
        require(_endAt > _startAt, "invalid range");

        round.startAt = _startAt;
        round.endAt = _endAt;
        round.votePrice = _votePrice;

        round.roundSinger = _signer;

        uint256 prev = 0;
        round.category.push(0);
        for (uint256 i = 0; i < _category.length; i++) {
            uint256 curr = _category[i];
            require(curr > prev);
            round.hasCategory[curr] = true;
            round.category.push(curr);

            prev = curr;
        }
    }

    function _resetPool() external onlyOwner {
        Round storage round = _rounds[currentRound];
        round.matchingPoolCategorial[0] = 34.3 ether;
    }

    function setValidProjects(uint256[] calldata _p) external onlyOwner {
        mapping(uint256 => bool) storage validPorjects = _rounds[currentRound]
            .validProjects;
        for (uint256 i = 0; i < _p.length; i++) {
            validPorjects[_p[i]] = true;
        }
    }

    function roundOver() external onlyOwner {
        require(_rounds[currentRound].endAt < block.timestamp);
        currentRound++;
    }

    function setTexPoint(uint256 _taxPoint) external onlyOwner {
        require(TAX_POINT <= UNIT);
        TAX_POINT = _taxPoint;
    }

    function setRoundTime(uint256 _startAt, uint256 _endAt) external onlyOwner {
        require(_endAt > _startAt, "invalid range");

        Round storage round = _rounds[currentRound];
        round.startAt = _startAt;
        round.endAt = _endAt;
    }

    function banProject(uint256 _p) external onlyOwner {
        Project storage project = _projects[_p];
        require(project.status == ProjectStatus.Normal);
        project.status = ProjectStatus.Banned;

        emit BanProject(_p, true);
    }

    // function unbanProject(uint256 _p) external onlyOwner {
    // 	Project storage project = _projects[_p];
    // 	require(project.status == ProjectStatus.Banned);
    // 	project.status = ProjectStatus.Normal;

    // 	emit BanProject(_p, false);
    // }

    function adjustProjectArea(
        uint256 _p,
        uint256 _area,
        string memory _reason
    ) external onlyOwner {
        Round storage round = _rounds[currentRound];

        uint256 category = _projects[_p].categoryIdx;
        if (!round.hasCategory[category]) {
            category = 0;
        }

        uint256 oriArea = round.areas[_p];
        uint256 totalArea = round.totalVotesCategorial[category];
        assert(totalArea + _area >= totalArea);

        if (oriArea > 0 && _area == 0) {
            round.categoryInfo[category].projectNumber--;
        }

        round.areas[_p] = _area;
        round.totalVotesCategorial[category] = totalArea + _area - oriArea;

        emit AdjustProjectArea(currentRound, _p, _area, _reason);
    }

    function batchAdjustProjectArea(
        uint256[] calldata _p,
        uint256[] calldata _area
    ) external onlyOwner {
        require(_p.length == _area.length);

        Round storage round = _rounds[currentRound];

        for (uint256 i = 0; i < _p.length; i++) {
            uint256 p = _p[i];
            uint256 area = _area[i];

            uint256 category = _projects[p].categoryIdx;
            if (!round.hasCategory[category]) {
                category = 0;
            }

            uint256 oriArea = round.areas[p];
            uint256 totalArea = round.totalVotesCategorial[category];

            if (oriArea > 0 && area == 0) {
                round.categoryInfo[category].projectNumber--;
            }

            round.areas[p] = area;
            round.totalVotesCategorial[category] = totalArea + area - oriArea;

            emit AdjustProjectArea(currentRound, p, area, "");
        }
    }

    // ! discard
    // Using this method during round will cause problems in the statistics of
    // `categoryInfo.projectNumber`, which will completely affect the calculation
    // of matching pool distribution.

    // function adjustCategory(uint256 _p, uint256 _category) external onlyOwner {
    //     Project storage project = _projects[_p];
    //     require(project.status == ProjectStatus.Normal);
    //     Round storage round = _rounds[currentRound];

    //     if (block.timestamp > round.endAt) {
    //         // after round end
    //         project.validRound = currentRound + 1;
    //     } else {
    //         project.validRound = currentRound;
    //         if (round.areas[_p] > 0) {
    //             adjustProjectArea(_p, 0, "");
    //         }
    //     }
    //     project.categoryIdx = _category;

    //     emit AdjustCategory(currentRound, _p, _category);
    // }

    function batchAdjustCategoryBeforeRoundStart(
        uint256 _round,
        uint256 _category,
        uint256[] calldata _p
    ) external onlyOwner {
        Round storage round = _rounds[_round];
        require(block.timestamp < round.startAt);

        for (uint256 i = 0; i < _p.length; i++) {
            uint256 p = _p[i];
            Project storage project = _projects[p];
            require(project.status == ProjectStatus.Normal);

            project.validRound = _round;
            project.categoryIdx = _category;

            emit AdjustCategory(_round, p, _category);
        }
    }
}
