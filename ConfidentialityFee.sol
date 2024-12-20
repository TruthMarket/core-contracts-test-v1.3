// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

// import "./openzeppelin/contracts/utils/Context.sol";
// import "./openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// import {IERC721Enumerable} from "./openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol"; 

import {Status, I_TruthBox, I_FundManager, IERC20} from "./interface.sol";
import "./library.sol";
import {Error} from "./interfaceError.sol";

contract ConfidentialityFee is Error {

    // error InvalidFee();              
    error InvalidRate();             
    error NotInCompleted();   
    // error DeadlineNotReached();      

    error DeadlineOver();

    // =======================================================================================================

    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    address private DAO;
    I_TruthBox private NFTBOX;
    I_FundManager private FUND_MANAGER;
    IERC20 private FEE_TOKEN;

    uint8 internal _incrementRate;  // 2.0 * 100
    // uint256 internal _storageFee; 

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
    function setAddress (
        address nftBox_, 
        address fundM_, 
        address dao_,
        address token_
    ) public onlyAdmin {
        if (token_ != address(0)) {
            FEE_TOKEN = IERC20(token_);
        }
        if (fundM_ != address(0)) {
            FUND_MANAGER = I_FundManager(fundM_);
        }
        if (nftBox_ != address(0)) {
            NFTBOX = I_TruthBox(nftBox_);
        }
        if (dao_ != address(0)) {
            DAO = dao_;
        }
    }

    // ===========================================================================================================
    // TODO 
    function setIncrementRate(uint8 rate_) public onlyAdminDAO {
        if (rate_ == 0 || rate_ > 200) revert InvalidRate();
        _incrementRate = rate_;
    }

    // ==========================================================================================================
    //                                               TODO Pay fee function
    // ==========================================================================================================

    // If the caster wishes to extend the confidentiality period, they will need to pay Storing fee, which will not be refunded.

    // Extend the confidentiality period and modify the price
    function _extendDeadline(uint256 tokenId_, uint256 price_) private {
        uint256 deadline_ = NFTBOX.getDeadline(tokenId_) + 7 days; // 365----7
        NFTBOX.setDeadline(tokenId_, deadline_);
        uint256 price_2 = price_ * _incrementRate / 100;
        NFTBOX.setPrice(tokenId_,price_2);
    } 

    function _payConfiFee(uint256 tokenId_) private {
        uint256 amount_ = NFTBOX.getPrice(tokenId_);

        FUND_MANAGER.receiveConfiFee(msg.sender, tokenId_, amount_);
        
        // Extend the confidentiality period and modify the price
        _extendDeadline(tokenId_,amount_);
    }

    // Pay Confidentiality Fee
    // Safe payment, NFT must not be public and invalid
    function PayConfiFee(uint256 tokenId_) public {
        if (
            NFTBOX.getStatus(tokenId_) != Status.Completed
        ){
            revert NotInCompleted();
        }
        if (NFTBOX.getDeadline(tokenId_) < block.timestamp) revert DeadlineOver();
        _payConfiFee(tokenId_);
    }

    // ==========================================================================================================

    function incrementRate() public view returns (uint8) {
        return _incrementRate;
    }

}