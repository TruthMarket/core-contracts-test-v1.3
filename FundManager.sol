// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

// import {Context} from "./openzeppelin/contracts/utils/Context.sol";
import {Strings} from "./openzeppelin/contracts/utils/Strings.sol";
// import {Address} from "./openzeppelin/contracts/utils/Address.sol";
// import "./openzeppelin/contracts/token/ERC20/IERC20.sol";

// import {Error} from "./interfaceError.sol";
import "./FeeRate.sol";

contract FundManager is FeeRate {

    error ZeroAmount();             
    error WithdrawPaused();    
    error EmptyWithdrawList(); 
    error InsufficientAmount();
    error AlreadyProcessing();
    error InRefundPermitted();

    // =====================================================================================

    event OrderAmount(uint256 indexed amount);
    event RewardAmount(uint256 indexed amount);
    event Withdraw(address indexed owner, uint256 indexed amount);
    // event Refunds(address indexed owner, uint256 indexed amount);

    // uint256 private _totalOrdAmount;
    uint256 private _totalRewards;

    mapping(uint256 tokenId => mapping(address buyer => uint256 amount)) private _orderAmount;

    mapping(uint256 tokenId => uint256) private _minterRewards;
    mapping (uint256 tokenId => uint256) private _publicRewards;
    mapping(uint256 tokenId => mapping(address addr => uint256)) private _otherRewards;

    mapping(uint256 tokenId => bool) private _refundPermit;

    uint256 private _allocatedFunds;
    uint256 private _unallocatedFunds;

    bool private _pauseWithdraw;
    // bool private _pauseReceive;
    mapping(address => bool) private _isProcessing;

    // ====================================================================================================================

    // constructor() FeeRate (){

    // }

    function togglePauseWithdraw() public onlyAdmin returns (bool) {
        _pauseWithdraw = !_pauseWithdraw;
        return _pauseWithdraw;
    }

    modifier isProcessing() {
        if (_isProcessing[msg.sender]) revert AlreadyProcessing();
        _isProcessing[msg.sender] = true;
        _;
        _isProcessing[msg.sender] = false;
    }

    // ====================================================================================================================
    //                                   receive amount
    // ====================================================================================================================
    //
    function receiveServiceFee(address addr_, uint256 amount_) external {
        FEE_TOKEN.transferFrom(addr_, address(this), amount_);
        _totalRewards += amount_;
        _unallocatedFunds += amount_;
        emit RewardAmount(amount_);
    }

    //
    function receiveOrderAmount(
        address buyer_,
        uint256 tokenId_,
        uint256 amount_
    ) external {
        if (msg.sender != address(EXCHANGE)) revert InvalidContractCaller();
        FEE_TOKEN.transferFrom(buyer_, address(this), amount_);
        
        _orderAmount[tokenId_][buyer_] += amount_;
        // _totalOrdAmount += amount_;

        emit OrderAmount(amount_);
    }

    // receive Confidentiality Fee
    function receiveConfiFee(
        address buyer_,
        uint256 tokenId_,
        uint256 amount_
    ) external {
        FEE_TOKEN.transferFrom(buyer_, address(this), amount_);

        _totalRewards += amount_;
        // allocationSecretFee(tokenId_, amount_);
        uint256 serviceFee_ = (amount_ * _serviceFeeRate) / 100;
        _unallocatedFunds += serviceFee_;

        uint256 rewardAmount_ = (amount_ * _publicRewardRate) / 100;
        _publicRewards[tokenId_] += rewardAmount_;

        _minterRewards[tokenId_] = amount_ - serviceFee_ - rewardAmount_;

        emit RewardAmount(amount_);
    }

    // ==========================================================================================================
    //                                             TODO Calculate income
    // ==========================================================================================================

    // Calculate income distribution,
    // which can only be called in the completed state to distribute the income of official fees, sellers, and minters
    function Reward(uint256 tokenId_) external {
        if (msg.sender != address(BOX_STATUS)) revert InvalidContractCaller();
        if (_refundPermit[tokenId_]) revert InRefundPermitted();

        address buyer_ = EXCHANGE.buyerOf(tokenId_);
        uint256 amount_ = _orderAmount[tokenId_][buyer_];

        _allocationOrderAmount(tokenId_, amount_, buyer_);
        _orderAmount[tokenId_][buyer_] = 0; // Clear order amount
        // _totalOrdAmount -= amount_;
        _totalRewards += amount_;

        emit RewardAmount(amount_);
    }

    function _allocationOrderAmount(
        uint256 tokenId_,
        uint256 amount_,
        address buyer_
    ) private {
        uint256 serviceFee_ = (amount_ * _serviceFeeRate) / 100;
        _unallocatedFunds += serviceFee_;

        uint256 rewardAmount_ = (amount_ * _publicRewardRate) / 100;
        _publicRewards[tokenId_] += rewardAmount_;
        
        uint256 adminIncome_;
        uint256 buyerIncome_;
        uint256 completeIncome_;

        uint256 adminFeeRate_ = _adminFeeRate[tokenId_];
        uint256 buyerFeeRate_ = _buyerFeeRate[tokenId_];
        address completer_ = EXCHANGE.completerOf(tokenId_);

        if (adminFeeRate_ > 0) {
            adminIncome_ = (amount_ * adminFeeRate_) / 100;
            _otherRewards[tokenId_][Admin()] += adminIncome_;
        }
        if (buyerFeeRate_ > 0) {
            buyerIncome_ = (amount_ * buyerFeeRate_) / 100;
            _otherRewards[tokenId_][buyer_] += buyerIncome_;
        }
        if (completer_ != address(0)) {
            completeIncome_ = (amount_ * _completerRewardRate) / 100;
            _otherRewards[tokenId_][completer_] += completeIncome_;
        }

        uint256 minterIncome_ = amount_ - serviceFee_ - adminIncome_ - buyerIncome_ - completeIncome_ - rewardAmount_;

        _minterRewards[tokenId_] += minterIncome_;
    }

    // ====================================================================================================================
    //                                                 TODO Withdraw
    // ====================================================================================================================

    function withdrawRefund(uint256[] memory list_) public isProcessing {
        if (_pauseWithdraw) revert WithdrawPaused();
        if (list_.length == 0) revert EmptyWithdrawList();

        uint256 amount_;
        for (uint256 i = 0; i < list_.length; i++) {
            uint256 tokenId_ = list_[i];
            if (
                msg.sender != EXCHANGE.buyerOf(tokenId_) ||
                !_refundPermit[tokenId_] || 
                _orderAmount[tokenId_][msg.sender] == 0
            ) {
                continue;
            }
            amount_ += _orderAmount[tokenId_][msg.sender];
            _orderAmount[tokenId_][msg.sender] = 0;
            // _refundPermit[tokenId_] = false;
        }
        
        if ( amount_ == 0 ) revert ZeroAmount();
        FEE_TOKEN.transfer(msg.sender, amount_);

        emit Withdraw(msg.sender, amount_);
    }

    function withdrawOrder(uint256[] memory list_) public isProcessing {
        if (_pauseWithdraw) revert WithdrawPaused();
        if (list_.length == 0) revert EmptyWithdrawList();

        uint256 amount_;
        for (uint256 i = 0; i < list_.length; i++) {
            uint256 tokenId_ = list_[i];
            if (
                _orderAmount[tokenId_][msg.sender] > 0 &&
                msg.sender != EXCHANGE.buyerOf(tokenId_)
            ) {
                amount_ += _orderAmount[tokenId_][msg.sender];
                _orderAmount[tokenId_][msg.sender] = 0;
            }
        }
        if ( amount_ == 0 ) revert ZeroAmount();
        FEE_TOKEN.transfer(msg.sender, amount_);

        emit Withdraw(msg.sender, amount_);
    }

    function withdrawOtherRewards(uint256[] memory list_) public isProcessing {
        if (_pauseWithdraw) revert WithdrawPaused();
        if (list_.length == 0) revert EmptyWithdrawList();

        uint256 amount_;
        for (uint256 i = 0; i < list_.length; i++) {
            uint256 tokenId_ = list_[i];
            if (_otherRewards[tokenId_][msg.sender] != 0) {
                amount_ += _otherRewards[tokenId_][msg.sender];
                _otherRewards[tokenId_][msg.sender] = 0;
            }
        }
        if ( amount_ == 0 ) revert ZeroAmount();
        FEE_TOKEN.transfer(msg.sender, amount_);

        emit Withdraw(msg.sender, amount_);
    }

    // ====================================================================================================================

    // 
    function withdrawMinter(uint256[] memory list_) public isProcessing {
        if (_pauseWithdraw) revert WithdrawPaused();
        if (list_.length == 0) revert EmptyWithdrawList();

        uint256 amount_;
        for (uint256 i = 0; i < list_.length; i++) {
            uint256 tokenId_ = list_[i];
            if (_minterRewards[tokenId_] > 0) {
                amount_ += _minterRewards[tokenId_];
                _minterRewards[tokenId_] = 0;
            }
        }
        if ( amount_ == 0 ) revert ZeroAmount();
        FEE_TOKEN.transfer(msg.sender, amount_);

        emit Withdraw(msg.sender, amount_);
    }

    function withdrawPublicRewards(address sender_, uint256 tokenId_) external isProcessing {
        if (_pauseWithdraw) revert WithdrawPaused(); 
        if (msg.sender != BOX_STATUS) revert InvalidContractCaller();

        uint256 amount_ = _publicRewards[tokenId_];

        if ( amount_ == 0 ) revert ZeroAmount();
        FEE_TOKEN.transfer(sender_, amount_);
        _publicRewards[tokenId_]=0;
        emit Withdraw(sender_, amount_);
    }


    // ====================================================================================================================
    // TODO  
    // ====================================================================================================================

    function withdrawServiceFee(
        address addr_,
        uint256 amount_
    ) public onlyAdminDAO isProcessing {

        if (_pauseWithdraw) revert WithdrawPaused();
        if (_unallocatedFunds < amount_) revert InsufficientAmount();

        FEE_TOKEN.transfer(addr_, amount_);

        _allocatedFunds += amount_;
        _unallocatedFunds -= amount_;
        
        emit Withdraw(addr_, amount_);
    }

    // ====================================================================================================================
    //  TODO setter
    // ====================================================================================================================

    function setRefundPermit(
        uint256 tokenId_,
        bool permission_
    ) external {
        if (
            msg.sender != address(BOX_STATUS) && 
            msg.sender != address(EXCHANGE)
        ) {
            revert InvalidContractCaller();
        }
        _refundPermit[tokenId_] = permission_;
    }

    // ====================================================================================================================
    //  TODO getter
    // ====================================================================================================================
    // Get order amount
    function orderAmount(
        uint256 tokenId_,
        address addr_
    ) public view returns (uint256) {
        return _orderAmount[tokenId_][addr_];
    }

    function publicRewards(uint256 tokenId_) public view returns (uint256) {
        return _publicRewards[tokenId_];
    }

    function refundPermit(uint256 tokenId_) public view returns (bool) {
        return _refundPermit[tokenId_];
    }

    function otherRewards(
        uint256 tokenId_,
        address addr_
    ) public view returns (uint256) {
        return _otherRewards[tokenId_][addr_];
    }

    function minterRewards(uint256 tokenId_) public view returns (uint256) {
        return _minterRewards[tokenId_];
    }

    // ====================================================================================================================

    //
    function unallocatedFunds() public view returns (uint256) {
        return _unallocatedFunds;
    }
    function allocatedFunds() public view returns (uint256) {
        return _allocatedFunds;
    }

    // function totalOrderAmount() public view returns (uint256) {
    //     return _totalOrdAmount;
    // }

    // function totalWithdraw() public view returns(uint256) {
    //     return _totalWithdraw;
    // }

    function totalRewards() public view returns (uint256) {
        return _totalRewards;
    }

    function isPauseWithdraw() public view returns (bool) {
        return _pauseWithdraw;
    }

}
