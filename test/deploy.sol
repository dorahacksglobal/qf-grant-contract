// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

import { GrantFactory } from '../GrantFactory.sol';
import { Grant } from '../Grant.sol';

import { Controller } from '../controllers/base.sol';
import { TestCon } from '../controllers/TestCon.sol';
import { ProgressiveTaxCon } from '../controllers/ProgressiveTax.sol';

contract TestDeploy {
    event C(address addr, string name);

    GrantFactory public factory;

    constructor() {
        factory = new GrantFactory();
        Grant g = new Grant();
        factory.setTaxPoint(10000);
        factory.setGrantLib(address(g));

        Controller c = new TestCon();
        factory.setController(0, c);
        c = new ProgressiveTaxCon();
        factory.setController(1, c);
    }

    function deploy() external payable {
        uint256[] memory params = new uint256[](3);
        params[0] = 1600000000;
        params[1] = 1700000000;
        params[2] = 100;
        uint256[] memory idx = new uint256[](2);
        idx[0] = 0;
        idx[1] = 1;
        bytes[] memory conp = new bytes[](2);
        conp[0] = abi.encode(msg.sender);

        uint256 gidx = factory.grantCount();
        factory.createRound{ value: msg.value }(params, address(0), msg.value, idx, conp);

        emit C(address(factory.grants(gidx)), "grant");
    }

    function balanceOf (address addr) external view returns (uint256) {
        return addr.balance;
    }
}
