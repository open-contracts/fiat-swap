pragma solidity ^0.8.0;

import "https://github.com/open-contracts/protocol/blob/main/solidity_contracts/OpenContractRopsten.sol";

contract FiatSwap is OpenContractAlpha {

    mapping(bytes32 => address) seller;
    mapping(bytes32 => address) buyer;
    mapping(bytes32 => uint256) amount;
    mapping(bytes32 => uint256) lockedUntil;
    mapping(bytes32 => uint8) serviceId;


    function secondsLeft(bytes32 offerID) public view returns(int256) {
        return int256(lockedUntil[offerID]) - int256(block.timestamp);
    }

    function ethOffered(bytes32 offerID, uint8 serviceID) public view returns(uint256) {
        require(msg.sender == buyer[offerID], "This offer isn't for you.");
        require(serviceId[offerID] == serviceID, "This offer is using a different service.");
        return amount[offerID];
    }

    function computeOfferID(string memory sellerHandle, uint256 priceInCent, string memory transactionMessage, string memory secret) public pure returns(bytes32) {
        return keccak256(abi.encodePacked(sellerHandle, priceInCent, transactionMessage, secret));
    }

    function venmoPurchase(bytes32 oracleHash, address payable msgSender, bytes32 offerID) 
    public _oracle(oracleHash, msgSender, this.venmoPurchase.selector) returns(bool) {
        require(buyer[offerID] == msgSender, "This offer isn't for you.");
        require(serviceId[offerID] == 0, "This is not a Venmo offer");
        uint256 payment = amount[offerID];
        amount[offerID] = 0;
        return msgSender.send(payment);
    }

    function paypalPurchase(bytes32 oracleHash, address payable msgSender, bytes32 offerID) 
    public _oracle(oracleHash, msgSender, this.paypalPurchase.selector) returns(bool) {
        require(buyer[offerID] == msgSender, "This offer isn't for you.");
        require(serviceId[offerID] == 1, "This is not a PayPal offer");
        uint256 payment = amount[offerID];
        amount[offerID] = 0;
        return msgSender.send(payment);
    }

    function offer(address to, bytes32 offerID, uint8 serviceID, uint256 lockForSeconds) public payable {
        amount[offerID] = msg.value;
        buyer[offerID] = to;
        serviceId[offerID] = serviceID;
        lockedUntil[offerID] = block.timestamp + lockForSeconds;
        seller[offerID] = msg.sender;
    }

    function retract(bytes32 offerID) public returns(bool) {
        require(seller[offerID] == msg.sender, 'only seller can retract offer');
        require(lockedUntil[offerID] <= block.timestamp, "can't retract offer during the locking period. check 'secondsLeft()'");
        uint256 payment = amount[offerID];
        amount[offerID] = 0;
        return payable(msg.sender).send(payment);
    }
}

