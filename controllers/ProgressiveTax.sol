// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

import { GrantStore } from '../libs/store.sol';
import { Controller } from './base.sol';

contract ProgressiveTaxCon is GrantStore, Controller {
	uint256 private constant UNIT = 1000000;
	uint256 public constant TAX_THRESHOLD = 5000 * UNIT;

	function handleVote(uint256, uint256 _projectId, uint256, address) external view override returns (bool pass, uint256 weight) {
		Project storage project = _projects[_projectId];
		uint256 area = project.supportArea;
		if (_topArea == 0 || _totalSupportArea == 0 || area <= TAX_THRESHOLD) {
			return (true, UNIT);
		}
		// total votes < 1e30
		// area        < 1e66
		// area * UNIT < 1e72
		// No Overflow
		uint256 k1 = area * UNIT / _topArea;					// absolutely less than 1
		uint256 k2 = area * UNIT / _totalSupportArea;	// absolutely less than 1
		// assert(k1 <= UNIT && k2 <= UNIT);
		uint256 k = UNIT - k1 * k2 / UNIT;
		uint256 squareK = k * k / UNIT;

		return (true, squareK);
	}
}
