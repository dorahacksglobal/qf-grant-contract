// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

import { Grant } from '../Grant.sol';

contract TestVoter {
	constructor() payable {}

    function vote(Grant _grant, uint256 _projectId, uint256 _votes) external {
        (uint256 cost, bool votable) = _grant.votingCost(address(this), _projectId, _votes);
        require(votable);
        _grant.vote{ value: cost }(_projectId, _votes);
    }

	receive() external payable {}
}
