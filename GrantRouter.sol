// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import {GrantFactory} from "./GrantFactory.sol";

contract GrantRouter {
    bytes32 private constant FACTORY_SLOT =
        0xcb65f75ad82cc751d496a0c70e94909adb0fa70b75c14d2e4f54a334167ecd3b;

    constructor(GrantFactory _f) {
        assert(FACTORY_SLOT == keccak256("grant.router.factory"));
        _setFactory(_f);
    }

    function _setFactory(GrantFactory newFactory) internal {
        bytes32 slot = FACTORY_SLOT;
        assembly {
            sstore(slot, newFactory)
        }
    }

    function _factory() internal view returns (GrantFactory factory) {
        bytes32 slot = FACTORY_SLOT;
        assembly {
            factory := sload(slot)
        }
    }

    fallback() external payable {
        address i = _factory().GRANT_MAIN();
        assembly {
            calldatacopy(0, 0, calldatasize())

            let result := delegatecall(gas(), i, 0, calldatasize(), 0, 0)

            returndatacopy(0, 0, returndatasize())

            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
}
