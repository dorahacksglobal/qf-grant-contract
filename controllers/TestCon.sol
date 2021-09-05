// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

import { GrantStore } from '../libs/store.sol';
import { Controller } from './base.sol';

contract TestCon is GrantStore, Controller {
	uint256 private constant UNIT = 1000000;

	function handleVote(uint256 _idx, uint256, uint256, address _voter) external payable override returns (bool pass, uint256 weight) {
		(address sp) = abi.decode(consParams[_idx], (address));

		return (true, _voter == sp ? 100 * UNIT : UNIT);
	}
}
