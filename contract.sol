pragma solidity ^0.8.0;

import "https://github.com/open-contracts/protocol/blob/main/solidity_contracts/OpenContractRopsten.sol";

contract FiatSwap is OpenContractAlpha {
    
    mapping(bytes32 => address) seller;
    mapping(bytes32 => address) buyer;
    mapping(bytes32 => uint256) amount;
    mapping(bytes32 => uint256) lockedUntil;
    mapping(bytes32 => uint8) serviceID;


    function secondsLeft(bytes32 offerID) public view returns(int256) {
        return int256(lockedUntil[offerID]) - int256(block.timestamp);
    }

    function ethOffered(bytes32 offerID) public view returns(uint256) {
        require(msg.sender == buyer[offerID], "No ETH offered for you.");
        return amount[offerID];
    }


    function computeHash(string memory sellerVenmo, uint256 priceInCent, string memory transactionMessage, string memory secret) public pure returns(bytes32) {
        return keccak256(abi.encodePacked(sellerVenmo, priceInCent, transactionMessage, secret));
    }

    function venmoPurchase(bytes32 oracleHash, address payable msgSender, bytes32 offerID) 
    public _oracle(oracleHash, msgSender, this.venmoPurchase.selector) returns(bool) {
        require(buyer[offerID] == msgSender);
        require(serviceID[offerID] == 0);
        uint256 payment = amount[offerID];
        amount[offerID] = 0;
        return msgSender.send(payment);
    }

    function paypalPurchase(bytes32 oracleHash, address payable msgSender, bytes32 offerID) 
    public _oracle(oracleHash, msgSender, this.paypalPurchase.selector) returns(bool) {
        require(buyer[offerID] == msgSender);
        require(serviceID[offerID] == 1);
        uint256 payment = amount[offerID];
        amount[offerID] = 0;
        return msgSender.send(payment);
    }
    
    function offer(address to, bytes32 offerID, uint256 lockForSeconds, uint8 service) public payable {
        amount[offerID] = msg.value;
        buyer[offerID] = to;
        lockedUntil[offerID] = block.timestamp + lockForSeconds;
        seller[offerID] = msg.sender;
        serviceID[offerID] = service;
    }
    
    function retract(bytes32 offerID) public returns(bool) {
        require(seller[offerID] == msg.sender, 'only seller can retract offer');
        require(lockedUntil[offerID] <= block.timestamp, "can't retract offer during the locking period. check 'secondsLeft()'");
        uint256 payment = amount[offerID];
        amount[offerID] = 0;
        return payable(msg.sender).send(payment);
    }
}
