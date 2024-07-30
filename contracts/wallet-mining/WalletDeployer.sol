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

// interface IAuthorizer {
//     function can(address usr, address aim) external view returns (bool);
// }

/**
 * @title  WalletDeployer
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 * @notice A contract that allows deployers of Gnosis Safe wallets (v1.1.1) to be rewarded.
 *         Includes an optional authorization mechanism to ensure only expected accounts
 *         are rewarded for certain deployments.
 */
contract WalletDeployer {
    // Addresses of the Gnosis Safe Factory and Master Copy v1.1.1
    IGnosisSafeProxyFactory public constant fact =
        IGnosisSafeProxyFactory(0x76E2cFc1F5Fa8F6a5b3fC4c8F4788F0116861F9B);
    address public constant copy = 0x34CfAC646f301356fAa8B21e94227e3583Fe3F5F;

    uint256 public constant pay = 1 ether;
    address public immutable chief = msg.sender;
    address public immutable gem;

    address public mom;

    error Boom();

    constructor(address _gem) {
        gem = _gem;
    }

    /**
     * @notice Allows the chief to set an authorizer contract.
     * Can only be called once. TODO: double check.
     */
    function rule(address _mom) external {
        if (msg.sender != chief || _mom == address(0) || mom != address(0)) {
            revert Boom();
        }
        mom = _mom;
        console.log("rule:", mom);
    }

    /**
     * @notice Allows the caller to deploy a new Safe wallet and receive a payment in return.
     *         If the authorizer is set, the caller must be authorized to execute the deployment.
     * @param wat initialization data to be passed to the Safe wallet
     * @return aim address of the created proxy
     */
    function drop(bytes memory wat) external returns (address aim) {
        aim = fact.createProxy(copy, wat);
        console.log("aim:", aim);
        console.log("can:", can(msg.sender, aim));
        if (mom != address(0) && !can(msg.sender, aim)) {
            revert Boom();
        }
        IERC20(gem).transfer(msg.sender, pay);
    }

    // TODO(0xth3g450pt1m1z0r) put some comments
    function can(address u, address a) public view returns (bool) {
        bytes32 m;
        assembly {
            m := sload(0)
            if iszero(extcodesize(m)) {
                return(0, 0)
            }
        }

        bytes32 p;
        assembly {
            p := mload(0x40)
            mstore(0x40, add(p, 0x44))
            mstore(p, shl(0xe0, 0x4538c4eb))
            mstore(add(p, 0x04), u)
            mstore(add(p, 0x24), a)
        }

        console.log("Static Call");
        assembly {
            if iszero(staticcall(gas(), m, p, 0x44, p, 0x20)) {
                return(0, 0)
            }
        }

        bytes32 ret;
        assembly {
            ret := mload(p)
        }

        // console.log("Ret", abi.decode(ret, (bool)));

        // console.log("Check return data");
        assembly {
            if and(not(iszero(returndatasize())), iszero(ret)) {
                mstore(0x00, 0)
                return(0x00, 0x20)
            }
        }

        console.log("Check done");
        return true;

        // bytes32 m;
        // bytes32 p;
        // console.log("Check code size");
        // assembly {
        //     m := sload(0)
        //     if iszero(extcodesize(m)) {
        //         return(0, 0)
        //     }
        // }
        // console.log("Prepare call data");
        // assembly {
        //     p := mload(0x40)
        //     mstore(0x40, add(p, 0x44))
        //     mstore(p, shl(0xe0, 0x4538c4eb))
        //     mstore(add(p, 0x04), u)
        //     mstore(add(p, 0x24), a)
        // }
        // console.log("Call can");
        // bytes32 res;
        // assembly {
        //     res := staticcall(gas(), m, p, 0x44, p, 0x20)
        // }
        // console.log("Check res");
        // assembly {
        //     if iszero(res) {
        //         return(0, 0)
        //     }
        //     if and(not(iszero(returndatasize())), iszero(mload(p))) {
        //         return(0, 0)
        //     }
        // }
        // return true;
        // (bool success, bytes memory returndata) = mom.staticcall(
        //     abi.encodeWithSignature("can(address,address)", u, a)
        // );
        // console.log("success:", success);
        // require(success, "staticcall failed");
        // bool res = abi.decode(returndata, (bool));
        // console.log("res", res);
        // require(res, "not authorized");
        // return res;
    }
}
