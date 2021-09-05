// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

import { IERC20 } from "./interface/IERC20.sol";
import { GrantRouter } from './GrantRouter.sol';
import { Grant } from './Grant.sol';

import { Controller } from './controllers/base.sol';

contract GrantFactory {
	address payable public owner;

	address public GRANT_MAIN;
	uint256 public TAX_POINT;

	mapping(uint256 => address) public grants; 
	uint256 public grantCount; 

	mapping (uint256 => Controller) private _controller;

	constructor() {
		owner = payable(msg.sender);
	}

	event NewRound(address indexed round);
	event Upgrade(address indexed previous, address indexed current);
	event Tax(uint256 taxPoint);
	event UpgradeController(uint256 indexed idx, address controller);
	 
	modifier onlyOwner() {
		require(msg.sender == owner);
		_;
	}
	
	function setGrantLib(address _grant) external onlyOwner {
		emit Upgrade(GRANT_MAIN, _grant);
		GRANT_MAIN = _grant;
	}
	
	function setTaxPoint(uint256 _tax) external onlyOwner {
		TAX_POINT = _tax;
		emit Tax(_tax);
	}
	
	function setController(uint256 _idx, Controller _con) external onlyOwner {
		_controller[_idx] = _con;
		emit UpgradeController(_idx, address(_con));
	}
	
	function withdraw(uint256 _amount) external onlyOwner {
		owner.transfer(_amount);
	}
	
	function withdrawToken(IERC20 _token, uint256 _amount) external onlyOwner {
		require(_token.transfer(owner, _amount));
	}

	function tax(uint256 _input) view external returns (uint256) {
		if (_input == 0) {
			return 0;
		}
		uint256 c = _input * TAX_POINT;
		assert(c / TAX_POINT == _input);
		return c / 1000000;
	}

	function controller(uint256 _idx) view external returns (Controller) {
		return _controller[_idx];
	}

	function createRound(
		uint256[] memory _params, // start, end, votingUnit
		address _token,
		uint256[] memory _consIdx,
		bytes[] memory _consParams
	) public {
		GrantRouter r = new GrantRouter(this);
		Grant g = Grant(payable(r));
		g.initialize(this, payable(msg.sender), _params, _token, _consIdx, _consParams);

		grants[grantCount] = address(r);
		grantCount++;

		emit NewRound(address(g));
	}
	
	receive () external payable {}
}