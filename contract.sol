pragma solidity ^0.8.0;
import "https://github.com/open-contracts/ethereum-protocol/blob/main/solidity_contracts/OpenContractRopsten.sol";

contract FiatSwap is OpenContract {
    mapping(bytes32 => address) seller;
    mapping(bytes32 => address) buyer;
    mapping(bytes32 => uint256) amount;
    mapping(bytes32 => uint256) lockedUntil;

    constructor() {   
        setOracleHash(this.buyTokens.selector, 0x1b031522bb9787f5b1aec2276f526179bb5feb2c5d5f095ed4a4492e27972358);
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
    function buyTokens(address payable user, bytes32 offerID) public requiresOracle returns(bool) {
        require(buyer[offerID] == user, "The offer was made to a different buyer.");
        uint256 payment = amount[offerID];
        amount[offerID] = 0;
        return user.send(payment);
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
