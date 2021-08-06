// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

import { GrantRouter } from './GrantRouter.sol';
import { Grant } from './Grant.sol';

contract GrantFactory {
	address payable public owner;

	address public GRANT_MAIN;

	constructor() {
		owner = payable(msg.sender);
	}

	event NewRound(address indexed);
	
	function setGrantLib(address _grant) external {
		require(msg.sender == owner);
		GRANT_MAIN = _grant;
	}

	function createRound(
		uint256 _start,
		uint256 _end,
		address _token,
		uint256 _votingUnit,
		uint256 _votingPower,
		bool _progressiveTax
	) public {
		GrantRouter r = new GrantRouter(this);
		Grant g = Grant(payable(r));
		g.initialize(this, payable(msg.sender), _start, _end, _token, _votingUnit, _votingPower, _progressiveTax);

		emit NewRound(address(g));
	}
}