pragma solidity ^0.5.0;


contract Ownable {
    address public owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event OwnershipRenounced(address indexed previousOwner);

    // sets the original `owner` of the contract to the sender
    constructor() public {
        owner = msg.sender;
    }

    // throws if called by any account other than the owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner of the contract can call this method");
        _;
    }

    // allows the current owner to transfer control of the contract to a newOwner
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "new owner address can not be null");                               // black-hole check
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;                                                                                   // change owner
    }

    // allows the current owner to renounce control of the contract.
    function renounceOwnership() public onlyOwner {
        emit OwnershipRenounced(owner);
        owner = address(0);                                                                                 // set owner as void
    }
}


contract Heritable is Ownable {
    address private heir_;

    // time window in which the owner must notify they are not dead
    uint private heartbeatTimeout_;

    // time of the owner's death as given by the heir.
    uint private timeOfDeath_;

    event HeirChanged(address indexed owner, address indexed newHeir);
    event OwnerHeartbeated(address indexed owner);
    event OwnerProclaimedDead(
        address indexed owner,
        address indexed heir,
        uint timeOfDeath
    );
    event HeirOwnershipClaimed(
        address indexed previousOwner,
        address indexed newOwner
    );


    // throws if called by any account other than the heir
    modifier onlyHeir() {
    require(msg.sender == heir_, "Only heir of the contract can call this method");
    _;
    }


    // constructor creates the contract with the given heartbeat timeout and sets the default heir as void
    constructor(uint _heartbeatTimeout) public {
        setHeartbeatTimeout(_heartbeatTimeout);
        heir_ = address(0);
    }

    // set the heir of the contract
    function setHeir(address newHeir) public onlyOwner {
        require(newHeir != owner, "owner cannot be heir of itself");
        heartbeat();
        emit HeirChanged(owner, newHeir);
        heir_ = newHeir;
    }

    // returns the heir of the contract
    function heir() public view returns(address) {
        return heir_;
    }

    // returns the current heartbeat timeout
    function heartbeatTimeout() public view returns(uint) {
        return heartbeatTimeout_;
    }

    // returns the time of death of the owner
    function timeOfDeath() public view returns(uint) {
        return timeOfDeath_;
    }

    // sets the heir to point to void
    function removeHeir() public onlyOwner {
        heartbeat();
        heir_ = address(0);
    }

    // the heir can proclaim the owner's death. To claim the ownership, they will have to wait for `heartbeatTimeout` seconds.
    function proclaimDeath() public onlyHeir {
        require(ownerLives(), "The owner must be living before death is proclaimed");
        emit OwnerProclaimedDead(owner, heir_, timeOfDeath_);
        timeOfDeath_ = now;
    }

    // send a heartbeat to verify that the owner is still alive
    function heartbeat() public onlyOwner {
        emit OwnerHeartbeated(owner);
        timeOfDeath_ = 0;
    }

    // Allows the heir to transfer ownership (only if heartbeat has timed out)
    function claimHeirOwnership() public onlyHeir {
        require(!ownerLives(), "owner must be proclaimed dead before claiming the ownership");
        
        require(now >= timeOfDeath_ + heartbeatTimeout_, "atleast heartbeatTimeout_ amount of time must have passed between proclaimed death time and ownership claim");
        emit OwnershipTransferred(owner, heir_);
        emit HeirOwnershipClaimed(owner, heir_);
        owner = heir_;
        timeOfDeath_ = 0;
        heir_ = address(0);
    }

    // change the heartbeatTimeout
    function setHeartbeatTimeout(uint newHeartbeatTimeout) public onlyOwner {
        require(ownerLives(), "Owner must be alive to set new heartneat timeout");
        heartbeatTimeout_ = newHeartbeatTimeout;
    }

    // returns owner's living status
    function ownerLives() internal view returns (bool) {
        return timeOfDeath_ == 0;
    }
}


contract DeadMansSwitch is Heritable {
    event Sent(address indexed payee, uint amount, uint balance);
    event Received(address indexed payer, uint amount, uint balance);

    constructor(uint _heartbeatTimeout) Heritable(_heartbeatTimeout) public {}

    // wallet can receive funds
    function () external payable {
        emit Received(msg.sender, msg.value, address(this).balance);
    }

    // wallet can send funds
    function sendTo(address payee, uint amount) public onlyOwner {
        require(payee != address(0) && payee != address(this), "receiver cannot be void or the owner itself");
        require(amount > 0, "amount must be greater than zero");
        address(uint160(payee)).transfer(amount);
        emit Sent(payee, amount, address(this).balance);
    }
}