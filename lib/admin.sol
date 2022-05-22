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

    function roundStart(
        uint256 _startAt,
        uint256 _endAt,
        uint256 _votePrice,
        uint256[] memory _category
    ) external onlyOwner {
        Round storage round = _rounds[currentRound];
        require(round.startAt == 0);
        require(_endAt > _startAt, "invalid range");

        round.startAt = _startAt;
        round.endAt = _endAt;
        round.votePrice = _votePrice;

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
    ) public onlyOwner {
        Round storage round = _rounds[currentRound];

        uint256 category = _projects[_p].categoryIdx;
        if (!round.hasCategory[category]) {
            category = 0;
        }

        uint256 oriArea = round.areas[_p];
        uint256 totalArea = round.totalAreaCategorial[category];
        assert(totalArea + _area >= totalArea);

        round.areas[_p] = _area;
        round.totalAreaCategorial[category] = totalArea + _area - oriArea;

        emit AdjustProjectArea(currentRound, _p, _area, _reason);
    }

    function adjustCategory(uint256 _p, uint256 _category) external onlyOwner {
        Project storage project = _projects[_p];
        require(project.status == ProjectStatus.Normal);
        Round storage round = _rounds[currentRound];

        if (block.timestamp > round.endAt) {
            // after round end
            project.validRound = currentRound + 1;
        } else {
            project.validRound = currentRound;
            if (round.areas[_p] > 0) {
                adjustProjectArea(_p, 0, "");
            }
        }
        project.categoryIdx = _category;

        emit AdjustCategory(currentRound, _p, _category);
    }
}
