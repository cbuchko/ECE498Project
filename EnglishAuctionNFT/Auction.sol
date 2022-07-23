// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

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

contract EnglishAuction {
    event Start();
    event Bid(address indexed sender, uint256 amount);
    event Withdraw(address indexed bidder, uint256 amount);
    event End(address winner, uint256 amount);

    IERC721 public nft;
    uint256 public nftId;

    address payable public seller;
    uint256 public endAt;
    bool public started;
    bool public ended;

    address public highestBidder;
    uint256 public highestBid;

    mapping(address => uint256) balance;
    mapping(address => BidStruct[]) bids;

    struct BidStruct {
        bytes32 blindedBid;
        uint256 deposit;
    }

    constructor(
        address _nft,
        uint256 _nftId,
        uint256 _startingBid
    ) {
        nft = IERC721(_nft);
        nftId = _nftId;

        seller = payable(msg.sender);
        highestBid = _startingBid;
    }

    function start() external {
        require(!started, "started");
        require(msg.sender == seller, "not seller");

        nft.transferFrom(msg.sender, address(this), nftId);
        started = true;
        endAt = block.timestamp + 60;

        emit Start();
    }

    // function bid() external payable {
    //     require(started, "not started");
    //     require(block.timestamp < endAt, "ended");
    //     // require(msg.value > highestBid, "value < highest");

    //     if (highestBidder != address(0)) {
    //         bids[highestBidder] += highestBid;
    //     }

    //     highestBidder = msg.sender;
    //     highestBid = msg.value;

    //     //emit Bid(msg.sender, msg.value);
    // }

    // Helper tester thing
    function generateBlindBid(uint256 value) public view returns (bytes32) {
        //keccak256(abi.encodePacked(value, fake, secret));
        return keccak256(abi.encode(value));
    }

    function bid(bytes32 _blindedBid) public payable {
        bids[msg.sender].push(
            BidStruct({blindedBid: _blindedBid, deposit: msg.value})
        );
    }

    // Track the highest bidder
    function placeBid(address bidder, uint256 value)
        internal
        returns (bool success)
    {
        if (value <= highestBid) {
            return false;
        }
        if (highestBidder != address(0)) {
            balance[highestBidder] += highestBid;
        }
        highestBid = value;
        highestBidder = bidder;
        return true;
    }

    // //go through all bids and figure out which one is the highest
    // function TallyBids(uint256 value) public {
    //     if (value >= balance[msg.sender]) return;

    //     bytes32 bid = generateBlindBid(value);
    //     for (uint256 i = 0; i < bids[msg.sender].length; i++) {
    //         if (bid == bids[msg.sender][i]) {
    //             if (value > winner_bid) {
    //                 winner_bid = value;
    //                 winner_addr = msg.sender;
    //             }
    //         }
    //         emit bidDisclosed(value);
    //     }
    //     return;
    // }

    function reveal(uint256[] memory _values) public {
        uint256 length = bids[msg.sender].length;
        uint256 refund;
        for (uint256 i = 0; i < length; i++) {
            BidStruct storage bidToCheck = bids[msg.sender][i];
            uint256 value = (_values[i]);
            if (bidToCheck.blindedBid != keccak256(abi.encode(value))) {
                continue;
            }
            refund += bidToCheck.deposit;
            if (!false && bidToCheck.deposit >= value) {
                if (placeBid(msg.sender, value)) {
                    refund -= value;
                }
            }
            bidToCheck.blindedBid = bytes32(0);
        }
        payable(msg.sender).transfer(refund);
    }

    function withdraw() external {
        uint256 bal = balance[msg.sender];
        if (bal > 0) {
            balance[msg.sender] = 0;
            payable(msg.sender).transfer((1 ether) * bal);
        }
    }

    function end() external {
        require(started, "not started");
        require(block.timestamp >= endAt, "not ended");
        require(!ended, "ended");

        ended = true;
        if (highestBidder != address(0)) {
            nft.safeTransferFrom(address(this), highestBidder, nftId);
            seller.transfer((1 ether) * highestBid);
        } else {
            nft.safeTransferFrom(address(this), seller, nftId);
        }

        emit End(highestBidder, highestBid);
    }
}
