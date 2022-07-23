pragma solidity >=0.7.0 <0.9.0;

/**
 * @title SealedEnvelope
 */

interface ContractInterface {
    function sendToken(uint256 tokenid, address to) external;

    function receiveToken(uint256 tokenid) external;
}

contract SealedEnvelope {
    address public winner_addr;
    address seller_addr;
    address contract_addr;
    uint256 reveal_time;
    bool finished;
    uint256 start_time;
    uint256 public auction_item;

    mapping(address => uint256) balance;

    function SealedEnvelope(
        uint256 _auction_item,
        uint256 bid_interval,
        uint256 post_bid_interval
    ) public {
        auction_item = _auction_item;
        seller_addr = msg.sender;

        reveal_time = block.timestamp + bid_interval;
        start_time = block.timestamp;
        finished = false;
    }

    // Add a bid and place the bid amount in escrow
    function PlaceBid(bytes32 bid) public payable isBidder {
        require(
            start_time <= block.timestamp && block.timestamp <= finish_time
        );

        balance[msg.sender] = msg.value;
    }

    function TallyBids() public inBidding returns () {
        uint length = bids[]
        return;
    }

    function handleTransfer() public payable returns (uint256) {
        uint256 new_balance = balance[msg.sender];
        if (new_balance > 0) {
            balance[msg.sender] = 0;
            payable(msg.sender).transfer(new_balance);
        }
        return new_balance;
    }

    //send auction item to winner and take funds
    function awardWinningBid() public isWinner inRevealing returns () {
        ContractInterface(contract_addr).sendToken(auction_item, msg.sender);
        uint256 new_balance = handleTransfer();
        return new_balance;
    }

    //return funds to loser
    function WithdrawLosingBid() public isLoser inRevealing returns (uint256) {
        uint256 new_balance = handleTransfer();
        return new_balance;
    }

    // Pays the seller of the auction item the amount
    function PaySeller() public isSeller inRevealing returns (uint256) {
        ContractInterface(contract_addr).sendToken(auction_item, msg.sender);
        uint256 new_balance = handleTransfer();
        return new_balance;
    }

    // Determine the winner of the auction
    function RevealWinner() public isSeller inRevealing {
        require(reveal_time <= block.timestamp);
    }

    // Return losing bids and auction_item to winning bidder
    function FinishAuction() public isSeller inRevealing {}

    modifier inBidding() {
        require(
            block.timestamp >= start_time && block.timestamp <= reveal_time
        );
        _;
    }

    modifier inRevealing() {
        require(
            block.timestamp >= reveal_time && block.timestamp <= finish_time
        );
        _;
    }

    modifier isSeller() {
        require(msg.sender == seller_addr);
    }

    modifier isBidder() {
        require(msg.sender != seller_addr);
    }

    modifier isWinner() {
        require(msg.sender == winner_addr && msg.sender != seller_addr);
    }

    modifier isLoser() {
        require(msg.sender != winner_addr && msg.sender != seller_addr);
    }
}
