// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import {GrantStorage} from "./storage.sol";

contract GrantUser is GrantStorage {
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
