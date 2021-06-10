
// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import { GrantFactory } from './GrantFactory.sol';

contract GrantRouter {
	GrantFactory public factory;

	constructor (GrantFactory _factory) {
		factory = _factory;
	}

	fallback () external payable {
		address i = factory.GRANT_MAIN();
		assembly {
			calldatacopy(0, 0, calldatasize())

			let result := delegatecall(gas(), i, 0, calldatasize(), 0, 0)

			returndatacopy(0, 0, returndatasize())

			switch result
			case 0 { revert(0, returndatasize()) }
			default { return(0, returndatasize()) }
		}
	}
}
