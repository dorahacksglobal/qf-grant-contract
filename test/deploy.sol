// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

import { GrantFactory } from '../GrantFactory.sol';
import { Grant } from '../Grant.sol';

import { Controller } from '../controllers/base.sol';
import { TestCon } from '../controllers/TestCon.sol';
import { ProgressiveTaxCon } from '../controllers/ProgressiveTax.sol';

contract test {
  event C(address addr, string name);

  function deploy() external payable {
    GrantFactory f = new GrantFactory();
    Grant g = new Grant();
    f.setTaxPoint(10000);
    f.setGrantLib(address(g));

    Controller c = new TestCon();
    f.setController(0, c);
    c = new ProgressiveTaxCon();
    f.setController(1, c);

    uint256[] memory params = new uint256[](3);
    params[0] = 1600000000;
    params[1] = 1700000000;
    params[2] = 100;
    uint256[] memory idx = new uint256[](2);
    idx[0] = 0;
    idx[1] = 1;
    bytes[] memory conp = new bytes[](2);
    conp[0] = abi.encode(msg.sender);

    f.createRound{ value: msg.value }(params, address(0), msg.value, idx, conp);

    emit C(address(f), "factory");
    emit C(address(f.grants(0)), "grant");
  }

  function balanceOf (address addr) external view returns (uint256) {
    return addr.balance;
  }
}