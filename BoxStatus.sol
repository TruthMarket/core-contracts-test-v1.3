// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

// import "./openzeppelin/contracts/utils/math/Math.sol";
// import "./openzeppelin/contracts/utils/Context.sol";
// import "./openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// import {IERC721Enumerable} from "./openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol"; 
import "./library.sol";

import {Status, I_TruthBox, I_Exchange, I_FundManager} from "./interface.sol";
import {Error} from "./interfaceError.sol";


contract BoxStatus is Error{

    // error DeadlineNotOver();
    error DeadlineOver();
    // error InRefundPermitted(); 
    error InvalidAuctionTime();   
    
    error AvailableBuyer();              
    error DeadlineNotOver();  

    // =======================================================================================================

    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    address private DAO;

    I_TruthBox private NFTBOX;
    I_Exchange private EXCHANGE;
    I_FundManager private FUND_MANAGER;
    // I_FeeRate private FEE_RATE;
    
    event Selling(uint256 tokenId_,  uint256 price_);
    event Auctioning(uint256 tokenId_, uint256 price_);
    event Deliver(uint256 tokenId_);
    event Refunding(uint256 tokenId_);
    event Complete(uint256 tokenId_);

    uint256 private _completeCounts; 
    // 必须添加一个public 获得奖励的变量。

    // =====================================================================================

    constructor() {
        StorageSlot.getAddressSlot(ADMIN_SLOT).value = msg.sender;
    }

    function Implementation() public view returns (address) {
        return StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value;
    }

    function upgrade(address newImplementation_) external onlyAdmin {
        if (newImplementation_.code.length == 0) revert InvalidImplementation();
        StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value = newImplementation_;
    }

    function Admin() public view returns (address) {
        return StorageSlot.getAddressSlot(ADMIN_SLOT).value;
    }

    function changeAdmin(address newAdmin_) public onlyAdmin {
        if (newAdmin_ == address(0)) revert ZeroAddress();
        StorageSlot.getAddressSlot(ADMIN_SLOT).value = newAdmin_;
    }

    modifier onlyAdmin() {
        if (msg.sender != Admin()) revert NotAdmin();
        _;
    }

    // ==========================================================================================================
    function setAddress(
        address nftBox_, 
        address exchange_,  
        address fundM_, 
        address dao_
    ) public onlyAdmin {
        if (fundM_ != address(0)) {
            FUND_MANAGER = I_FundManager(fundM_);
        }
        if (exchange_ != address(0)) {
            EXCHANGE = I_Exchange(exchange_);
        }
        if (nftBox_ != address(0)) {
            NFTBOX = I_TruthBox(nftBox_);
        }
        if (dao_ != address(0)) {
            DAO = dao_;
        }
    }

    //==================================================================================================
    //                                      Sell Functions 
    //==================================================================================================
    
    function _selling(uint256 tokenId_, uint256 price_) internal {
        NFTBOX.setStatus(tokenId_, Status.Selling);
        NFTBOX.setPrice(tokenId_, price_);
        NFTBOX.setDeadline(tokenId_, block.timestamp + 7 days); // 365----7

        emit Selling(tokenId_, price_);
    } 

    function sell(uint256 tokenId_, uint256 price_) external {
        if (NFTBOX.getStatus(tokenId_) != Status.Storing) revert InvalidStatus();
        if (msg.sender != address(EXCHANGE)) revert InvalidContractCaller();
        _selling(tokenId_, price_);
    }

    // ==========================================================================================================
    function _auctioning(uint256 tokenId_, uint256 price_) internal {
        NFTBOX.setStatus(tokenId_, Status.Auctioning);
        NFTBOX.setPrice(tokenId_, price_);
        // 30----2
        NFTBOX.setDeadline(tokenId_, block.timestamp + 3 days);

        emit Auctioning(tokenId_, price_);
    } 

    function auction(uint256 tokenId_, uint256 price_) external {
        if (NFTBOX.getStatus(tokenId_) != Status.Storing) revert InvalidStatus();

        if (msg.sender != address(EXCHANGE)) revert InvalidContractCaller();
        _auctioning(tokenId_, price_);
        
    }

    //==================================================================================================
    //                                  Buy Functions
    //==================================================================================================

    // function Buy(uint256 tokenId_) external returns(uint256) {
    //     if (msg.sender != address(EXCHANGE)) revert InvalidContractCaller();
    //     if (NFTBOX.getStatus(tokenId_) != Status.Selling) revert InvalidStatus();

    //     // NFTBOX.setDeadline(tokenId_, block.timestamp + 365 days); // 365----7
    //     return NFTBOX.getPrice(tokenId_);
    // }

    function bid(uint256 tokenId_) external returns(uint256) {
        if (msg.sender != address(EXCHANGE)) revert InvalidContractCaller();
        if (NFTBOX.getStatus(tokenId_) != Status.Auctioning) revert InvalidStatus();
        uint256 deadline = NFTBOX.getDeadline(tokenId_);
        if (deadline < block.timestamp) revert DeadlineOver();
        
        NFTBOX.setDeadline(tokenId_, deadline + 3 days); // 30---3
        uint256 price_ = NFTBOX.getPrice(tokenId_);

        uint256 price_2 = price_ * FUND_MANAGER.bidIncrementRate() / 100; // If bidIncrementRate is 110, then it is 110%
        NFTBOX.setPrice(tokenId_, price_2);
        return price_;
        
    }

    // ==========================================================================================================
    //                                        TODO   Deliver Functions
    // ==========================================================================================================                                          


    function deliver(uint256 tokenId_) external {
        if (msg.sender != address(EXCHANGE)) revert InvalidContractCaller();
        if (!_tokenInBlackList(tokenId_)) {
            NFTBOX.setStatus(tokenId_, Status.Delivered);
            emit Deliver(tokenId_);
        }
    }

    function _tokenInBlackList(uint256 tokenId_) private returns(bool) { 
        if (NFTBOX.isBlackTokenId(tokenId_)){
            FUND_MANAGER.setRefundPermit(tokenId_, true);
            return true;
        } else {
            return false;
        }
    }

    // ===========================================================================================

    // 
    function requestRefund(uint256 tokenId_) external {
        if (msg.sender != address(EXCHANGE)) revert InvalidContractCaller();
        if (NFTBOX.getStatus(tokenId_) != Status.Delivered) revert InvalidStatus();
        
        if (!_tokenInBlackList(tokenId_)) {
            NFTBOX.setStatus(tokenId_, Status.Refunding);
            emit Refunding(tokenId_);
        }
    }

    // ==========================================================================================================
    // 
    function cancelRefund(uint256 tokenId_) external {
        if (msg.sender != address(EXCHANGE)) revert InvalidContractCaller();
        if (NFTBOX.getStatus(tokenId_) != Status.Refunding) revert InvalidStatus();
        
        if (!_tokenInBlackList(tokenId_)){
            _complete(tokenId_);
            FUND_MANAGER.Reward(tokenId_);
        } 
    }

    // ==========================================================================================================

    // Agree to the refund request, set it to public status, 
    // and publicly disclose the fileURI and password, 
    // which can only be called by the seller, administrator, and DAO

    function agreeRefund(uint256 tokenId_) external {
        if (msg.sender != address(EXCHANGE)) revert InvalidContractCaller();

        if (NFTBOX.getStatus(tokenId_) != Status.Refunding) revert InvalidStatus();
        FUND_MANAGER.setRefundPermit(tokenId_, true);
        _complete(tokenId_);
    }

    function refuseRefund(uint256 tokenId_) external {
        if (msg.sender != address(EXCHANGE)) revert InvalidContractCaller();
        if (NFTBOX.getStatus(tokenId_) != Status.Refunding) revert InvalidStatus();

        if (!_tokenInBlackList(tokenId_)){
            _complete(tokenId_);
            FUND_MANAGER.Reward(tokenId_);
        } 
    }

    // ==================================================================================================
    //                                        Complete Functions
    // ==================================================================================================
    function _complete(uint256 tokenId_) internal {
        NFTBOX.setStatus(tokenId_, Status.Completed);
        NFTBOX.setDeadline(tokenId_, block.timestamp + 3 days); // 30----3
        // Safe to use unchecked here because:
        // 1. This is a simple counter
        // 2. The number of completed NFTs will never reach uint256 max
        unchecked {
            _completeCounts ++;
        }
        emit Complete(tokenId_);
    }

    function complete(uint256 tokenId_) external {
        if (msg.sender != address(EXCHANGE)) revert InvalidContractCaller();
        if (NFTBOX.getStatus(tokenId_) != Status.Delivered ) revert InvalidStatus();
        
        if (!_tokenInBlackList(tokenId_)) {
            _complete(tokenId_);
            FUND_MANAGER.Reward(tokenId_);
        }
    }

    // ==========================================================================================================
    //                                              Public noBuyer Functions
    // ==========================================================================================================

    // If it exceeds the auction or sales cycle and no one bids, 
    // the NFT's fileURI and password will be made public, 
    // which can only be called by the owner, administrator, and DAO
    function _checkCondition(uint256 tokenId_)  internal view{
        if (NFTBOX.getStatus(tokenId_) != Status.Selling && 
            NFTBOX.getStatus(tokenId_) != Status.Auctioning) {
            revert InvalidStatus();
        }
        if ( NFTBOX.getDeadline(tokenId_) >= block.timestamp ) revert DeadlineNotOver(); 
        if ( EXCHANGE.buyerOf(tokenId_) != address(0)) revert AvailableBuyer();
            
    }
    // only minter or admin can call
    function PublicNoBuyer(uint256 tokenId_, string memory fileCID_, string memory password_ ) public {
        _minterOrAdmin(tokenId_);

        _checkCondition(tokenId_);
        NFTBOX.setCidPassword(tokenId_, fileCID_, password_);
    }

    function _minterOrAdmin(uint256 tokenId_) internal view {
        if (msg.sender != Admin() && msg.sender != NFTBOX.minterOf(tokenId_)) {
            revert InvalidCaller();
        }
    }

    // =========================================================================================================
    
    // Set as public, NFT cannot be public or invalid
    function _checkOverDeadline(uint256 tokenId_)  internal view{
        if (NFTBOX.getStatus(tokenId_) != Status.Completed) {
            revert InvalidStatus();
        }
        if (NFTBOX.getDeadline(tokenId_) >= block.timestamp) revert DeadlineNotOver();

    } 

    // Public NFT can only be called by the owner and can be made public at any time, 
    // but once it is made public, it cannot be kept confidential again

    function PublicBuyer(uint256 tokenId_, string memory fileCID_, string memory password_) public {
        if (NFTBOX.getStatus(tokenId_) != Status.Completed) revert InvalidStatus();
        if (msg.sender != EXCHANGE.buyerOf(tokenId_)) revert InvalidCaller();

        NFTBOX.setCidPassword(tokenId_, fileCID_, password_);
        FUND_MANAGER.withdrawPublicRewards(msg.sender, tokenId_);
    }

    // Public NFT, which administrators can call, 
    // can only be made public after the confidentiality period has expired
    function PublicOverDeadline(uint256 tokenId_, string memory fileCID_, string memory password_) public {
        _minterOrAdmin(tokenId_);

        _checkOverDeadline(tokenId_);

        NFTBOX.setCidPassword(tokenId_, fileCID_, password_);
        FUND_MANAGER.withdrawPublicRewards(msg.sender, tokenId_);
    } 
    // =========================================================================================================
    

    function completeCounts() public view returns(uint256) {
        return _completeCounts;
    }

}