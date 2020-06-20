const DMSWallet = artifacts.require("DeadMansSwitch");
const Web3 = require('web3');
const web3 = new Web3();
web3.setProvider(new web3.providers.HttpProvider('http://127.0.0.1:7545'));


const void_address = '0x0000000000000000000000000000000000000000';
const one_eth = web3.utils.toWei('1', 'ether');
const default_time_of_death = 50000;            // default_time_of_death is the timeout given to the contract deployement by default (see : 2_deploy_contract.js)

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

contract('Dead Man\'s Switch Tests:', async (accounts) => {
    it("should check heir to be void by default", async () => {
        let instance = await DMSWallet.deployed();
        let heir_address = await instance.heir.call();
        assert.equal(heir_address, void_address);
    });

    it("should check default heartbeatTimeout to be equal to default_time_of_death", async () => {
        let instance = await DMSWallet.deployed();
        let heartbeat_timeout = await instance.heartbeatTimeout.call();
        assert.equal(heartbeat_timeout, default_time_of_death);
    });

    it("should check default time of death to be zero", async () => {
        let instance = await DMSWallet.deployed();
        let time_of_death = await instance.timeOfDeath.call();
        assert.equal(time_of_death, 0);
    });

    it("should check changing the heartbeat timeout works", async () => {
        let instance = await DMSWallet.deployed();
        await instance.setHeartbeatTimeout(999);
        let heartbeat_timeout = await instance.heartbeatTimeout.call();
        assert.equal(heartbeat_timeout, 999);
    });

    it("should check that removing the heir sets the heir to be void and resets the time of death to zero", async () => {
        let instance = await DMSWallet.deployed();
        await instance.removeHeir.call();
        let heir_address = await instance.heir.call();
        let time_of_death = await instance.timeOfDeath.call();
        assert.equal(heir_address, void_address);
        assert.equal(time_of_death, 0);
    });

    it("should check that changing the heir works", async () => {
        let instance = await DMSWallet.deployed();
        await instance.setHeir(accounts[2]);
        let heir_address = await instance.heir.call();
        assert.equal(heir_address, accounts[2]);
    });

    it("should be able to receive ether", async () => {
        let instance = await DMSWallet.deployed();
        let balanceBefore = await web3.eth.getBalance(instance.address);
        await web3.eth.sendTransaction({from: accounts[2], to: instance.address, value: one_eth});
        let balanceAfter = await web3.eth.getBalance(instance.address);
        assert.equal(parseInt(balanceAfter), parseInt(balanceBefore) + parseInt(one_eth));
    });
    
    it("should be able to send ether", async () => {
        let instance = await DMSWallet.deployed();
        await web3.eth.sendTransaction({from: accounts[2], to: instance.address, value: one_eth});
        let balanceBefore = await web3.eth.getBalance(instance.address);
        await instance.sendTo(accounts[2], one_eth);
        let balanceAfter = await web3.eth.getBalance(instance.address);
        // balance is below because of gas usage
        assert.isBelow(parseInt(balanceAfter), parseInt(balanceBefore) + parseInt(one_eth));
    });

    // make sure that this test runs last
    it("should check that proclaiming death and claiming the assets works", async () => {
        let instance = await DMSWallet.deployed();
        const accounts = await web3.eth.getAccounts();
        const heir = accounts[2];
        const new_timeout = 1;
        await instance.setHeir(heir);
        
        await instance.setHeartbeatTimeout(new_timeout);      // for fast death validation timeout
        
        await instance.proclaimDeath({from: heir});
        await sleep((new_timeout+1)*1000);              // wait for the time of death to expire
        await instance.claimHeirOwnership({from: heir});

        const new_owner = await instance.owner.call();      // get the new owner of the contract
        assert.equal(new_owner, heir);
    });
})