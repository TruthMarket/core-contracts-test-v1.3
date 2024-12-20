// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

// import "./openzeppelin/contracts/utils/Context.sol";
// import "./openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20, I_Exchange, I_TruthBox} from "./interface.sol";
import "./library.sol";
import {Error} from "./interfaceError.sol";
    
contract FeeRate is Error {

    error InvalidRate();          

    // error MaxAdminFeeRateExceeded(); 
    // error MaxBuyerFeeRateExceeded(); 

    // =====================================================================================

    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    address internal DAO; 

    IERC20 internal FEE_TOKEN; 
    I_Exchange internal EXCHANGE; 
    I_TruthBox internal NFTBOX; 
    address internal BOX_STATUS;

    uint256 internal _bidIncrementRate;  
    uint256 internal _serviceFeeRate; 

    mapping (uint256 tokenId => uint256 rate_) internal _adminFeeRate; 
    mapping (uint256 tokenId => uint256 rate_) internal _buyerFeeRate; 

    uint256 internal _completerRewardRate;
    uint256 internal _publicRewardRate; 

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
    // =====================================================================================================

    function setAddress(
        address nftBox_, 
        address box_status_, 
        address exchange_, 
        address dao_,
        address token_
    ) public onlyAdmin {
        if (token_ != address(0)) {
            FEE_TOKEN = IERC20(token_);
        }
        if (exchange_ != address(0)) {
            EXCHANGE = I_Exchange(exchange_);
        }
        if (box_status_ != address(0)) {
            BOX_STATUS = box_status_;
        }
        if (nftBox_ != address(0)) {
            NFTBOX = I_TruthBox(nftBox_);
        }
        if (dao_ != address(0)) {
            DAO = dao_;
        }
    }


    // ==========================================================================================================

    // 
    function setServiceFeeRate(uint256 Rate_) public onlyAdminDAO {
        if (Rate_ > 10) revert InvalidRate();
        _serviceFeeRate = Rate_;
    }
    // 110
    function setBidIncrementRate(uint256 rate_) public onlyAdminDAO {
        if (rate_ <= 100 || rate_ > 150) revert InvalidRate();
        _bidIncrementRate = rate_;
    }

    // 3
    function setPublicRewardRate(uint256 Rate_) public onlyAdminDAO {
        if (Rate_ > 5) revert InvalidRate();
        _publicRewardRate = Rate_;
    }

    // 3
    function setCompleterRewardRate(uint256 Rate_) public onlyAdminDAO {
        if (Rate_ > 10) revert InvalidRate();
        _completerRewardRate = Rate_;
    }

    // ==========================================================================================================
    //                                          Increase additional rates
    // ==========================================================================================================

    function addAdminFeeRate(uint256 tokenId_, uint256 amount_) external {
        if (msg.sender != address(EXCHANGE)) revert InvalidContractCaller();
        unchecked {
            _adminFeeRate[tokenId_] += amount_;
        }
        if (_adminFeeRate[tokenId_] > 10) {
            _adminFeeRate[tokenId_] = 10;
        }
    }

    function addBuyerFeeRate(uint256 tokenId_, uint256 amount_) external {
        if (msg.sender != address(EXCHANGE)) revert InvalidContractCaller();
        unchecked {
            _buyerFeeRate[tokenId_] += amount_;
        }
        if (_buyerFeeRate[tokenId_] > 50) {
            _buyerFeeRate[tokenId_] = 50;
        }
    }

    // ==========================================================================================================
    //                                         get fee rate
    // ==========================================================================================================

    function adminFeeRate(uint256 tokenId_) public view returns(uint256) {
        return _adminFeeRate[tokenId_];
    }

    function buyerFeeRate(uint256 tokenId_) public view returns(uint256) {
        return _buyerFeeRate[tokenId_];
    }

    function completerRewardRate() public view returns(uint256) {
        return _completerRewardRate;
    }

    function bidIncrementRate() public view returns (uint256) {
        return _bidIncrementRate;
    }

    function publicRewardRate() public view returns (uint256) {
        return _publicRewardRate;
    }

    function serviceFeeRate() public view returns (uint256) {
        return _serviceFeeRate;
    }

}