// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "./openzeppelin/contracts/utils/Context.sol";

import {I_TruthBox, I_BoxStatus, I_FundManager, I_EncryptionStorage} from "./interface.sol";
import "./library.sol";
import {Error} from "./interfaceError.sol";

contract ExchangeTime is Context, Error {

    error InvalidPeriod();       

    // =====================================================================================

    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    address internal DAO;

    I_BoxStatus internal BOX_STATUS; 
    I_TruthBox internal NFTBOX; 
    I_FundManager internal FUND_MANAGER; 
    // I_FeeRate internal FEE_RATE; 
    I_EncryptionStorage internal ENCRYPTION_STORAGE;

    uint256 internal _deliveryPeriod;
    uint256 internal _refundRequestPeriod;
    uint256 internal _refundReviewPeriod; 

    mapping (uint256 tokenId => uint256 time) internal _deliveryTimestamp; 
    mapping (uint256 tokenId => uint256 time) internal _refundRequestTimestamp; 
    mapping (uint256 tokenId => uint256 time) internal _purchaseTimestamp; 

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

    modifier onlyAdminDAO() {
        if (msg.sender != Admin() && msg.sender != DAO) revert NotAdminOrDAO();
        _;
    }

    // ==========================================================================================================
    function setAddress(
        address nftBox_, 
        address box_status_, 
        address fundM_, 
        address encryption_, 
        address dao_
    ) public onlyAdmin {
        if (fundM_ != address(0)) {
            FUND_MANAGER = I_FundManager(fundM_);
        }
        if (encryption_ != address(0)) {
            ENCRYPTION_STORAGE = I_EncryptionStorage(encryption_);
        }
        if (box_status_ != address(0)) {
            BOX_STATUS = I_BoxStatus(box_status_);
        }
        if (nftBox_ != address(0)) {
            NFTBOX = I_TruthBox(nftBox_);
        }
        if (dao_ != address(0)) {
            DAO = dao_;
        }

    }

    // ==========================================================================================================
    // 7~30  ||  2~5
    function setDeliveryPeriod(uint256 period_) public onlyAdminDAO {
        if (period_ < 2 days || period_ > 5 days) revert InvalidPeriod();
        _deliveryPeriod = period_;
    }
    // 7~15  || 1~3
    function setRefundRequestPeriod(uint256 period_) public onlyAdminDAO {
        if (period_ < 1 days || period_ > 3 days) revert InvalidPeriod();
        _refundRequestPeriod = period_;
    }
    // 15~60  ||  2~7
    function setRefundReviewPeriod(uint256 period_) public onlyAdminDAO {
        if (period_ < 2 days || period_ > 7 days) revert InvalidPeriod();
        _refundReviewPeriod = period_;
    }

    // ==========================================================================================================


    function purchaseTimestamp(uint256 tokenId_) public view returns (uint256) {
        return _purchaseTimestamp[tokenId_];
    }

    function deliveryTimestamp(uint256 tokenId_) public view returns (uint256) {
        return _deliveryTimestamp[tokenId_];
    }

    function refundRequestTimestamp(uint256 tokenId_) public view returns (uint256) {
        return _refundRequestTimestamp[tokenId_];
    }

    function deliveryPeriod() public view returns (uint256) {
        return _deliveryPeriod;
    }
    function refundRequestPeriod() public view returns (uint256) {
        return _refundRequestPeriod;
    }
    function refundReviewPeriod() public view returns (uint256) {
        return _refundReviewPeriod;
    }

}
