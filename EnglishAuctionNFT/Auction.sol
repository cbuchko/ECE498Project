// SPDX-License-Identifier: MIT

// https://youtu.be/ZeFjGJpzI7E?t=840

// TODO
// Go back to using hashes to bid (done, untested)
// Use nonce to make bids secure (done, untested)
// Add modifiers to ensure steps are done in the correct order (bid -> reveal -> end -> withdraw) (half done)
// Cleanup/modify code
// Simplify NFT process

pragma solidity ^0.8.13;

import "hardhat/console.sol";

interface IERC721 {
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function transferFrom(
        address,
        address,
        uint256
    ) external;
}

contract SealedEnvelopeAuction {
    event Start();
    event End(address winner, uint256 amount);

    IERC721 public nft;
    uint256 public nftId;

    address payable public seller;

    enum Stage {
        Unstarted,
        Bidding,
        Revealing,
        Ending
    }

    Stage currentStage = Stage.Unstarted;

    address public highestBidder;
    uint256 public highestBid;

    mapping(address => uint256) balance;
    mapping(address => BidStruct[]) bids;

    struct BidStruct {
        bytes32 blindedBid;
        uint256 deposit;
    }

    constructor(address _nft, uint256 _nftId) {
        nft = IERC721(_nft);
        nftId = _nftId;

        seller = payable(msg.sender);
        highestBid = 0;
    }

    function start() external isSeller isUnstarted {
        nft.transferFrom(msg.sender, address(this), nftId);
        currentStage = Stage.Bidding;

        emit Start();
    }

    // Would be implemented client side, here for demo purposes
    function generateBlindBid(uint256 value, string memory nonce)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(value, nonce));
    }

    function bid(bytes32 hashedBid) public payable isBidder isBidStage {
        console.log("Bid value entered");
        bids[msg.sender].push(
            BidStruct({blindedBid: hashedBid, deposit: msg.value})
        );
    }

    // Track the highest bidder
    function placeBid(address bidder, uint256 value)
        internal
        returns (bool success)
    {
        console.log("Bid value", value);
        console.log("Highest bid", highestBid);

        if (value <= highestBid) {
            return false;
        }

        console.log("New highest bid");

        // Return bid to old highest bidder (to be obtained by them through withdraw())
        if (highestBidder != address(0)) {
            console.log("Bid successful, return old highest bid", highestBid);
            balance[highestBidder] += highestBid;
        }

        // Set the new highest bidder
        highestBid = value;
        highestBidder = bidder;
        return true;
    }

    function reveal(uint256[] memory _values, string[] memory _nonces)
        public
        isBidder
        isRevealStage
    {
        uint256 length = bids[msg.sender].length;
        console.log("In reveal");
        for (uint256 i = 0; i < length; i++) {
            console.log("Revealing transaction", i);
            BidStruct storage bidToCheck = bids[msg.sender][i];
            uint256 value = (_values[i]);
            string memory nonce = (_nonces[i]);
            console.log("Transaction value", value);
            if (
                bidToCheck.blindedBid !=
                keccak256(abi.encodePacked(value, nonce))
            ) {
                continue;
            }
            console.log("Hash check passed");
            if ((bidToCheck.deposit / 1000000000000000000) >= value) {
                console.log("Deposit check passed");
                if (placeBid(msg.sender, value)) {
                    console.log("Place bid sucessful");
                    // Check if the bid is successful (i.e. is the new hgihest bid)
                    console.log(
                        "Bid successful, add difference bidToCheck.deposit - value",
                        bidToCheck.deposit - value
                    );
                    balance[msg.sender] += ((bidToCheck.deposit /
                        1000000000000000000) - value); // Refund the user their deposit minus their actual bid value if they are the highest bidder
                }
            } else {
                console.log("Deposit was less than bid");
                balance[msg.sender] += (bidToCheck.deposit /
                    1000000000000000000); // If the deposit is not as large as the bit refund the deposit
            }
            bidToCheck.blindedBid = bytes32(0);
        }
    }

    // At the end of the auction allow losers to withdraw their bid
    function withdraw() external isBidder isEnded {
        uint256 bal = balance[msg.sender];
        console.log("Withdraw", bal);
        if (bal > 0) {
            balance[msg.sender] = 0;
            payable(msg.sender).transfer(bal * 1000000000000000000);
        }
    }

    function end() external isSeller isRevealStage {
        if (highestBidder != address(0)) {
            console.log("Transfer winning bid to seller and NFT to winner");
            nft.safeTransferFrom(address(this), highestBidder, nftId);
            seller.transfer(highestBid * 1000000000000000000);
        } else {
            nft.safeTransferFrom(address(this), seller, nftId);
        }

        currentStage = Stage.Ending;
        emit End(highestBidder, highestBid);
    }

    function startReveal() external {
        currentStage = Stage.Revealing;
    }

    modifier isSeller() {
        require(msg.sender == seller, "Not seller");
        _;
    }

    modifier isBidder() {
        require(msg.sender != seller, "Not bidder");
        _;
    }

    modifier isUnstarted() {
        require(currentStage == Stage.Unstarted, "Already started");
        _;
    }

    modifier isStarted() {
        require(currentStage == Stage.Bidding, "Not started");
        _;
    }

    modifier isEnded() {
        require(currentStage == Stage.Ending, "Not ended");
        _;
    }

    modifier isBidStage() {
        require(currentStage == Stage.Bidding, "Not bid stage");
        _;
    }

    modifier isRevealStage() {
        require(currentStage == Stage.Revealing, "Not reveal stage");
        _;
    }
}
