pragma solidity ^0.8.0;

contract OpenContract {
    OpenContractsHub private hub = OpenContractsHub(0x2d7FBE2EbCd2026b6a4fD21923F5221d104e194c);
 
    function setOracle(bytes4 selector, bytes32 oracleID) internal {
        hub.setOracle(selector, oracleID);
    }
 
    modifier requiresOracle {
        require(msg.sender == address(hub), "Can only be called via Open Contracts Hub.");
        _;
    }
}

interface OpenContractsHub {
    function setOracle(bytes4, bytes32) external;
}

contract FiatSwap is OpenContract {
    mapping(bytes32 => address) seller;
    mapping(bytes32 => address) buyer;
    mapping(bytes32 => uint256) amount;
    mapping(bytes32 => uint256) lockedUntil;

    constructor() {   
        // setOracle(this.buyTokens.selector, 0x1234); // developer mode, allows any oracleID for 'buyTokens'
    }

    // every offer has a unique offerID which can be computed from the off-chain transaction details.
    function offerID(string memory sellerHandle, uint256 priceInCent, string memory transactionMessage,
                     string memory paymentService, string memory buyerSellerSecret) public pure returns(bytes32) {
        return keccak256(abi.encode(sellerHandle, priceInCent, transactionMessage, paymentService, buyerSellerSecret));
    }

    // sellers should lock their offers, to give the buyer time to make and verify their online payment.
    function secondsLocked(bytes32 offerID) public view returns(int256) {
        return int256(lockedUntil[offerID]) - int256(block.timestamp);
    }

    // every offer has a unique offerID which can be computed with this function.
    function weiOffered(bytes32 offerID) public view returns(uint256) {
        require(msg.sender == buyer[offerID], "No ether offered for you at this offerID.");
        require(secondsLocked(offerID) > 1200, "Offer isn't locked for at least 20min. Ask the seller for more time.");
        return amount[offerID];
    }

    // to make an offer, the seller specifies the offerID, the buyer, and the time they give the buyer
    function offerTokens(bytes32 offerID, address buyerAddress, uint256 lockForSeconds) public payable {
        amount[offerID] = msg.value;
        buyer[offerID] = buyerAddress;
        lockedUntil[offerID] = block.timestamp + lockForSeconds;
        seller[offerID] = msg.sender;
    }

    // to accept a given offerID and buy tokens, buyers have to verify their payment 
    // using the oracle whose oracleID was specified in the constructor at the top
    function buyTokens(address payable msgSender, bytes32 offerID) public requiresOracle returns(bool) {
        require(buyer[offerID] == msgSender);
        uint256 payment = amount[offerID];
        amount[offerID] = 0;
        return msgSender.send(payment);
    }

    // sellers can retract their offers once the time lock lapsed.
    function retractOffer(bytes32 offerID) public returns(bool) {
        require(seller[offerID] == msg.sender, "Only seller can retract offer.");
        require(secondsLocked(offerID) <= 0, "Can't retract offer during the locking period.");
        uint256 payment = amount[offerID];
        amount[offerID] = 0;
        return payable(msg.sender).send(payment);
    }
}
