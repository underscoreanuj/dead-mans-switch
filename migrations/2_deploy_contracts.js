var DeadMansSwitch = artifacts.require("./DeadMansSwitch.sol");

module.exports = function(deployer) {
    deployer.deploy(DeadMansSwitch, 50000);
}