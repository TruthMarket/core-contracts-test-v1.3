// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

// import "@openzeppelin/contracts/utils/Address.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// interface I_FeeRate{

    // function addAdminFeeRate(uint256 tokenId_, uint256 amount_) external returns (bool);
    // // EXCHANGE
    // function addBuyerFeeRate(uint256 tokenId_, uint256 amount_) external returns (bool);
    // EXCHANGE

    // function adminFeeRate(uint256 tokenId_) external;
    // function buyerFeeRate(uint256 tokenId_) external;
    // function completeFeeRate() external;

    // function serviceFee(uint256 amount_) external view returns (uint256);
    // function sellerFee(uint256 amount_) external view returns (uint256);
    // function completeFee(uint256 amount_) external view returns (uint256);
    // function buyerFee(uint256 tokenId_, uint256 amount_) external view returns (uint256);
    // function adminFee(uint256 tokenId_, uint256 amount_) external view returns (uint256);

    // function storingFee() external view returns (uint256);
    // function bidIncrementRate() external view returns (uint256);
    // function secretGain() external view returns (uint256);
    // function serviceFeeRate() external view returns (uint256);
    // function sellerFeeRate() external view returns (uint256);
// }

interface I_FundManager{
    function addAdminFeeRate(uint256 tokenId_, uint256 amount_) external;
    // EXCHANGE
    function addBuyerFeeRate(uint256 tokenId_, uint256 amount_) external;
    // EXCHANGE
    function bidIncrementRate() external view returns (uint256);

    function receiveServiceFee(address minter_, uint256 fee_) external;
    function receiveOrderAmount(address buyer_, uint256 tokenId_, uint256 money_) external;
    // EXCHANGE
    function receiveConfiFee(address buyer_, uint256 tokenId_, uint256 money_) external;

    function Reward(uint256 tokenId_) external;
    // BOX_STATUS
    function refundPermit(uint256 tokenId_) external view returns (bool);
    function setRefundPermit(uint256 tokenId_,bool permission_) external;
    // BOX_STATUS  EXCHANGE
    function orderAmount(uint256 tokenId_, address addr_) external view returns (uint256);
    // function otherRewards(uint256 tokenId_, address addr_) external view returns (uint256);
    // function minterRewards(uint256 tokenId_) external view returns(uint256);
    // function unallocatedServiceFee() external view returns(uint256);
    function withdrawPublicRewards(address sender_, uint256 tokenId_) external;

}

enum Status {Storing, Selling, Auctioning, Delivered, Refunding, Completed, Published }
interface I_TruthBox{

    
    function isBlackTokenId(uint256 tokenId_) external view returns (bool);
    // function isBlackList(address blackA_) external view returns (bool);
    // function inDeadline(uint256 tokenId_) external view returns (bool);
    
    function getStatus(uint256 tokenId_) external view returns(Status);
    function setStatus(uint256 tokenId_, Status status_) external;
    // BOX_STATUS
    function getPrice(uint256 tokenId_) external view returns(uint256);
    function setPrice(uint256 tokenId_, uint256 price_) external ;
    // BOX_STATUS PAY_SECRET_FEE
    function getDeadline(uint256 tokenId_) external view returns(uint256);
    function setDeadline(uint256 tokenId_, uint256 deadline_) external ;
    // BOX_STATUS PAY_SECRET_FEE
    function minterOf(uint256 tokenId_) external view returns(address);
    function totalSupply() external view returns (uint256);

    // NFTBox2
    function setCidPassword(uint256 tokenId_, string memory fileCID_, string memory password_) external ;
    //  BOX_STATUS
}

interface I_BoxStatus{

    
    function sell(uint256 tokenId_, uint256 price_) external;
    // EXCHANGE
    function auction(uint256 tokenId_, uint256 price_) external;
    // EXCHANGE
    // function sellOverTime(uint256 tokenId_) external;
    // EXCHANGE
    // function auctionOverTime(uint256 tokenId_) external;
    // EXCHANGE
    // function buy(uint256 tokenId_) external returns(uint256);
    // EXCHANGE
    function bid(uint256 tokenId_) external returns(uint256);
    // EXCHANGE
    function deliver(uint256 tokenId_) external;
    // function deliverOverTime(uint256 tokenId_) external;
    // EXCHANGE
    function requestRefund(uint256 tokenId_) external;
    // EXCHANGE
    function refuseRefund(uint256 tokenId_) external;
    // EXCHANGE
    function agreeRefund(uint256 tokenId_) external;
    // EXCHANGE
    // function agreeRefundOverTime(uint256 tokenId_, string memory fileCID_, string memory password_) external;
    // EXCHANGE
    function cancelRefund(uint256 tokenId_) external;
    // EXCHANGE
    function complete(uint256 tokenId_) external;
    // EXCHANGE
    // function CompletedOverTime(uint256 tokenId_) external;
    // EXCHANGE
}

// interface I_BoxPublic{

//     function PublicNoBuyer(uint256 tokenId_) external;
//     function PublicNoBuyer(uint256 tokenId_, string memory fileCID_, string memory password_) external;
// }

interface I_Exchange{


    function buyerOf(uint256 tokenId_) external view returns(address);
    // function buyerList(address buyer_) external view returns (uint256[] memory);
    function sellerOf(uint256 tokenId_) external view returns(address);
    function completerOf(uint256 tokenId_) external view returns(address);
}

interface IERC20 {

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function decimals() external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

interface I_EncryptionStorage {

    function setPublicKey_minter(uint256 tokenId_,bytes memory key_) external;
    function setPublicKey_buyer(uint256 tokenId_,bytes memory key_) external;
    function setPrivateKey_buyer(uint256 tokenId_,bytes memory key_) external;
    // function setEncryptoData_buyer(uint256 tokenId_, bytes memory fileCid_, bytes memory password_) external;
    // EXCHANGE 
    function setCryptData_buyer(uint256 tokenId_, bytes memory fileCid_iv, bytes memory password_iv, bytes memory fileCid_, bytes memory password_) external;
    // NFTBox
    function setCryptData_office(uint256 tokenId_, bytes memory fileCid_iv, bytes memory password_iv, bytes memory fileCid_, bytes memory password_) external;
    // NFTBox
}
