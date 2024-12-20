// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC721/ERC721.sol)

pragma solidity ^0.8.20;

import {Status} from "./interface.sol";
import "./ExchangeTime.sol";

contract Exchange is ExchangeTime {

    // error Paused();                    
    error InvalidPrice();

    error InAuctioning();         

    // error EmptyPublicKey();           

    error InRefundDeadline(); 
    error InReviewDeadline();          

    error InRefundPermitted();  

    error NoPurchaseTimestamp(); 
    error Purchased();
    error Delivered(); 
    error NoDeliveryTime();
    error HasRequestRefundTime();
    error NoRequestRefundTime();
    error NotOver100days();

    // =======================================================================================================

    event SellTime(uint256 indexed tokenId_, uint256 time_);
    event Buyer(address buyer, uint256 indexed tokenId_);
    event Bidder(
        address indexed buyer,
        uint256 indexed tokenId_,
        uint256 indexed price_
    );
    event Completer(address sender, uint256 indexed tokenId_);

    mapping (uint256 tokenId => address buyer) private _buyer;
    mapping (uint256 tokenId => address addr) internal _completer; 

    // mapping (uint256 tokenId => address seller) private _seller;

    // mapping(uint256 tokenId => bytes) internal _publicKey_buyer;

    // bool private _isPause;
    // mapping (uint256 tokenId => uint256 step) private _step;


    // mapping (address msgsender => bool) private _oneFuncing;

    // ========================================================================================================

    // constructor () {
    // }

    // ========================================================================================================
    //                                           TODO Sell related functions
    //========================================================================================================

    function Sell(
        uint256 tokenId_, 
        uint256 price_,
        bytes memory publicKey_minter,
        bytes memory fileCid_iv_office,
        bytes memory password_iv_office,
        bytes memory fileCid_office,
        bytes memory password_office
    ) public {
        if (NFTBOX.isBlackTokenId(tokenId_)) revert Blacklisted();
        if (msg.sender != NFTBOX.minterOf(tokenId_)) revert NotMinter();
        if (price_ < 100) revert InvalidPrice();

        BOX_STATUS.sell(tokenId_, price_);

        ENCRYPTION_STORAGE.setPublicKey_minter(
            tokenId_,
            publicKey_minter
        );
        ENCRYPTION_STORAGE.setCryptData_office(
            tokenId_,
            fileCid_iv_office,
            password_iv_office,
            fileCid_office,
            password_office
        );

        emit SellTime (tokenId_, block.timestamp);
    }

    function Purchase(uint256 tokenId_, bytes memory buyerPublicKey_) public {
        if (_purchaseTimestamp[tokenId_] != 0 ) revert Purchased(); 
        if (NFTBOX.isBlackTokenId(tokenId_)) revert Blacklisted();
        if (NFTBOX.getStatus(tokenId_) != Status.Selling) revert InvalidStatus();
        address buyer_ = _msgSender();
        _buyer[tokenId_] = buyer_;

        _purchaseTimestamp[tokenId_] = block.timestamp;

        ENCRYPTION_STORAGE.setPublicKey_buyer(tokenId_, buyerPublicKey_);

        uint256 payAmount_ = NFTBOX.getPrice(tokenId_);
        FUND_MANAGER.receiveOrderAmount(buyer_, tokenId_, payAmount_); // 转账

        emit Buyer(buyer_, tokenId_);
    }

    // ========================================================================================================
    //                                         TODO Auction related functions
    // ========================================================================================================

    function Auction(
        uint256 tokenId_,
        uint256 price_,
        bytes memory publicKey_minter,
        bytes memory fileCid_iv_office,
        bytes memory password_iv_office,
        bytes memory fileCid_office,
        bytes memory password_office
    ) public {
        if (NFTBOX.isBlackTokenId(tokenId_)) revert Blacklisted();
        if (msg.sender != NFTBOX.minterOf(tokenId_)) revert NotMinter();
        if (price_ < 100) revert InvalidPrice();

        BOX_STATUS.auction(tokenId_,price_);
        
        ENCRYPTION_STORAGE.setPublicKey_minter(
            tokenId_,
            publicKey_minter
        );
        ENCRYPTION_STORAGE.setCryptData_office(
            tokenId_,
            fileCid_iv_office,
            password_iv_office,
            fileCid_office,
            password_office
        );

        emit SellTime (tokenId_, block.timestamp);

    }

    function Bid(uint256 tokenId_, bytes memory buyerPublicKey_) public {
        if (NFTBOX.isBlackTokenId(tokenId_)) revert Blacklisted();
        address buyer_ = _msgSender();
        _buyer[tokenId_] = buyer_;

        _purchaseTimestamp[tokenId_] = block.timestamp;

        ENCRYPTION_STORAGE.setPublicKey_buyer(tokenId_, buyerPublicKey_);

        uint256 price_ = BOX_STATUS.bid(tokenId_);

        uint256 payAmount_ = _calcPayMoney(buyer_, tokenId_, price_);
        FUND_MANAGER.receiveOrderAmount(buyer_, tokenId_, payAmount_); // need approve to FUND_MANAGER。

        emit Bidder(buyer_, tokenId_, price_);
    }

    // ========================================================================================================
    //                                                  Money
    // ========================================================================================================

    function calcPayMoney(uint256 tokenId_) public view returns (uint256) {
        uint256 price_ = NFTBOX.getPrice(tokenId_);
        return _calcPayMoney(msg.sender, tokenId_, price_);
    }

    function _calcPayMoney(
        address buyer_,
        uint256 tokenId_,
        uint256 price_
    ) internal view returns (uint256) {
        uint256 balance_ = FUND_MANAGER.orderAmount(tokenId_, buyer_);
        uint256 amount_ = price_ - balance_;
        return amount_;
    }

    // ========================================================================================================
    //                                         TODO Verify order related functions
    // ========================================================================================================

    function Deliver(
        uint256 tokenId_,
        bytes memory fileCid_iv_buyer,
        bytes memory password_iv_buyer,
        bytes memory fileCid_buyer,
        bytes memory password_buyer
    ) public {
        uint256 purchaseTime_ = _purchaseTimestamp[tokenId_];
        // purchase or bid are called 
        if (purchaseTime_ == 0 ) revert NoPurchaseTimestamp(); 
        if (_deliveryTimestamp[tokenId_] != 0) revert Delivered(); 

        if (msg.sender == Admin()) {
            // If it is an administrator, a 3% handling fee will be charged
            FUND_MANAGER.addAdminFeeRate(tokenId_, 3);
        } else if (msg.sender != NFTBOX.minterOf(tokenId_)) {
            
            return ;
        }
        // caller = Admin or Minter
        _calcBuyerFeeRate(tokenId_);
        ENCRYPTION_STORAGE.setCryptData_buyer(
            tokenId_,
            fileCid_iv_buyer,
            password_iv_buyer,
            fileCid_buyer,
            password_buyer
        );
        BOX_STATUS.deliver(tokenId_);
        _deliveryTimestamp[tokenId_] = block.timestamp;
    }

    // Check if it exceeds the diliver time. If it exceeds the diliver time, the income will be deducted
    function _calcBuyerFeeRate(uint256 tokenId_) internal {
        Status status = NFTBOX.getStatus(tokenId_);
        if (status != Status.Auctioning && status != Status.Selling) {
            revert InvalidStatus();
        }
        uint256 baseTime;
        if (status == Status.Auctioning) {
            baseTime = NFTBOX.getDeadline(tokenId_);
            if (baseTime >= block.timestamp) revert InAuctioning();
        } else {
            baseTime = _purchaseTimestamp[tokenId_];
        }

        uint256 deadline = baseTime + _deliveryPeriod + 3 hours; // 1 days----3 hours
        if (deadline > block.timestamp) {
            return ;
        }
        // If it exceeds the time limit, the income will be deducted.
        // For every day of delay, 1% will be deducted and returned to the buyer,

        uint256 st_ = (block.timestamp - baseTime - _deliveryPeriod) / 3 hours; // 1 days----3 hours
        FUND_MANAGER.addBuyerFeeRate(tokenId_, st_);
    }
    
    
    function DeliverOverdue(
        uint256 tokenId_
    ) public {
        uint256 purchaseTime_ = _purchaseTimestamp[tokenId_];
        // purchase or bid are called 
        if (purchaseTime_ == 0 ) revert NoPurchaseTimestamp(); 
        if (_deliveryTimestamp[tokenId_] != 0) revert Delivered(); 
        if (
            msg.sender == Admin() && 
            msg.sender == NFTBOX.minterOf(tokenId_)
        ) {
            revert InvalidCaller();
        } 
        // caller = buyer or other 
        // 100----3
        if (purchaseTime_ + 3 days > block.timestamp) revert NotOver100days(); 
        FUND_MANAGER.setRefundPermit(tokenId_, true);
    }
    
    // ========================================================================================================
    //                                          TODO Refund function
    // ========================================================================================================

    function RequestRefund(
        uint256 tokenId_,
        bytes memory buyerPrivateKey_
    ) public {
        if (msg.sender != _buyer[tokenId_]) revert NotBuyer();
        if (FUND_MANAGER.refundPermit(tokenId_)) revert InRefundPermitted();

        if (inRefundDeadline(tokenId_)) {
            BOX_STATUS.requestRefund(tokenId_);
            ENCRYPTION_STORAGE.setPrivateKey_buyer(tokenId_, buyerPrivateKey_);
            _refundRequestTimestamp[tokenId_] = block.timestamp;

        } else {
            BOX_STATUS.complete(tokenId_);
        }
    }

    // Check the refund time. Within the refund time,
    // you can apply for a refund (set to refunding mode),
    function inRefundDeadline(uint256 tokenId_) public view returns (bool) {
        if (_deliveryTimestamp[tokenId_] == 0 ) revert NoDeliveryTime();
        if(_refundRequestTimestamp[tokenId_] != 0) revert HasRequestRefundTime();
            
        uint256 deadline_ = _deliveryTimestamp[tokenId_] + _refundRequestPeriod;
        if (deadline_ >= block.timestamp) {
            return true; // If the refund period has not expired, a refund can be applied for
        } else {
            return false; //
        }
    }

    // ========================================================================================================

    function CancelRefund(uint256 tokenId_) public {
        if (msg.sender != _buyer[tokenId_]) revert NotBuyer();
        if (FUND_MANAGER.refundPermit(tokenId_)) revert InRefundPermitted();

        BOX_STATUS.cancelRefund(tokenId_);
    }

    function AgreeRefund(
        uint256 tokenId_
    ) public {
        if (FUND_MANAGER.refundPermit(tokenId_)) revert InRefundPermitted();
        if(_refundRequestTimestamp[tokenId_] == 0) revert NoRequestRefundTime();

        if (
            msg.sender != NFTBOX.minterOf(tokenId_) &&
            msg.sender != Admin() &&
            msg.sender != DAO
        ) {
            revert InvalidCaller();
        }
        BOX_STATUS.agreeRefund(tokenId_);
    }
    // everybody can call
    function AgreeRefundOverdue(
        uint256 tokenId_
    ) public {
        if (FUND_MANAGER.refundPermit(tokenId_)) revert InRefundPermitted();
        // If within the refund review period,
        // the administrator and Minter need to agree to the refund
        if (inReviewDeadline(tokenId_)) revert InReviewDeadline();

        BOX_STATUS.agreeRefund(tokenId_);
    }

    // ========================================================================================================

    function RefuseRefund(
        uint256 tokenId_
    ) public onlyAdminDAO{
        if (FUND_MANAGER.refundPermit(tokenId_)) revert InRefundPermitted();

        BOX_STATUS.refuseRefund(tokenId_);

    }

    function inReviewDeadline(uint256 tokenId_) public view returns (bool) {
        if (_refundRequestTimestamp[tokenId_] == 0) revert NoRequestRefundTime();
        uint256 refundReviewDeadline_ = _refundRequestTimestamp[tokenId_] + _refundReviewPeriod;

        if (refundReviewDeadline_ >= block.timestamp) {
            return true; // Refunds can be refused within the approved refund period
        } else {
            return false; //
        }
    }

    // =========================================================================================================
    //                                           finalize related functions
    // ========================================================================================================

    //
    function CompleteOrder(uint256 tokenId_) public {
        if (FUND_MANAGER.refundPermit(tokenId_)) revert InRefundPermitted();

        if (msg.sender == _buyer[tokenId_]) {
            // If the seller diliver and has not yet applied for a refund, it can be set as completed
            if (_deliveryTimestamp[tokenId_] == 0 ) revert NoDeliveryTime(); 
            if (_refundRequestTimestamp[tokenId_] != 0 ) revert HasRequestRefundTime(); 

        } else {
            // If the refund application deadline has passed and no refund has been applied for,
            // it can be set as completed
            if (inRefundDeadline(tokenId_)) revert InRefundDeadline();

            if (msg.sender!= NFTBOX.minterOf(tokenId_)) {
                // FUND_MANAGER.addCompleter(tokenId_, sender_);
                _completer[tokenId_] = msg.sender;
                emit Completer(msg.sender, tokenId_);
            }
        }
        BOX_STATUS.complete(tokenId_);
    }

    // ========================================================================================================
    //                                          TODO Getter function
    // ========================================================================================================

    function buyerOf(uint256 tokenId_) public view returns (address) {
        return _buyer[tokenId_];
    }

    function completerOf(uint256 tokenId_) public view returns(address) {
        return _completer[tokenId_];
    }

    //========================================================================================================
    //
    //========================================================================================================

}
