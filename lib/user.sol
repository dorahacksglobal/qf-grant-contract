// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import {GrantStorage} from "./storage.sol";

contract GrantUser is GrantStorage {
    function updateMinVotesProject(uint256 _r, uint256 _p) external {
        Round storage round = _rounds[_r];
        Project storage project = _projects[_p];

        require(project.validRound <= _r);

        uint256 category = project.categoryIdx;
        if (!round.hasCategory[category]) {
            category = 0;
        }

        Category storage categoryInfo = round.categoryInfo[category];

        uint256 pArea = round.areas[_p];
        require(pArea > 0 && pArea < categoryInfo.minVotes);

        categoryInfo.minVotes = pArea;
        categoryInfo.minVotesProject = _p;
    }
    // function toggleActiveStatus(uint256 _p, bool _active) external {
    //     require(address(uint160(_p)) == msg.sender);
    //     Project storage project = _projects[_p];
    //     require(project.status == ProjectStatus.Normal);
    //     if (_active) {
    //         project.participationRoundIdx = 1 ether;
    //     } else if (_rounds[currentRound].startAt < block.timestamp) {
    //         project.participationRoundIdx = currentRound - 1;
    //     } else {
    //         project.participationRoundIdx = currentRound;
    //     }
    // }
    // function changeCategory(uint256 _p, uint256 _category) external {
    //     require(address(uint160(_p)) == msg.sender);
    //     Project storage project = _projects[_p];
    //     require(project.status == ProjectStatus.Normal);
    //     Round storage round = _rounds[currentRound];
    //     project.categoryIdx = _category;
    //     if (block.timestamp < round.startAt || round.startAt == 0) {
    //         // before round start
    //         project.validRound = currentRound;
    //     } else if (block.timestamp > round.endAt) {
    //         // after round end
    //         project.validRound = currentRound + 1;
    //     } else {
    //         revert();
    //     }
    // }
}
