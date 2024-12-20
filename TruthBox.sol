// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "./openzeppelin/contracts/token/ERC721/ERC721.sol";
import {I_EncryptionStorage} from "./interface.sol";
import {Error} from "./interfaceError.sol";
import "./library.sol";

contract TruthBox is ERC721, Error {
    
    error TokenNotExists();          
    // error TokenAlreadyInvalid();     

    error EmptyPassword();         
    error PublicTimeNotEnd();       

    error BlackTokenIdNotExist();

    // error InPublicDeadline();           
    error EmptyFileInfo();           
    error EmptyTokenInfo();          

    // =====================================================================================

    // event Storing(uint256 tokenId_);
    event Public(uint256 tokenId_);

    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    address internal DAO;
    address internal BOX_STATUS;
    address private CONFI_FEE;
    address internal EXCHANGE;
    // I_FundManager internal FUND_MANAGER;
    I_EncryptionStorage internal ENCRYPTION_STORAGE; // use for update

    string private _logoURI;
    string private _network;
    string private _uriSuffix;
    
    enum Status {Storing, Selling, Auctioning, Delivered, Refunding, Completed, Published}
    
    struct BOX {
        string _infoCID; 
        string _tokenURI; 
        string _fileCID; 
        string _password; 
        uint256 _price; 
        uint256 _deadline; 
        Status _status; 
    }

    mapping (uint256 tokenId => BOX) internal NFTBOX; 

    mapping (uint256 tokenId => address minter) internal _minter; 
    // mapping (address minter => uint256[] ) internal _minterList; 

    // ==================================================================================================
    uint256 internal _nextTokenId; 
    uint256 internal _blackSupply; 
    
    mapping (uint256 tokenId => bool) internal _blackTokenIds; 
    // uint256 internal _invalidSupply; 
    // mapping (uint256 tokenId => bool) internal _isInvalid; 
    // mapping (address => bool) internal blackListAddress;

    // ==================================================================================================

    constructor() ERC721('Truth Market NFT', 'TMN') {
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
        address box_status_, 
        address exchange_, 
        address encryption_,
        address payFee_, 
        address dao_
    ) public onlyAdmin {
        if (payFee_ != address(0)) {
            CONFI_FEE = payFee_;
        }
        if (exchange_ != address(0)) {
            EXCHANGE = exchange_;
        }
        // if (fund_ != address(0)) {
        //     FUND_MANAGER = I_FundManager(fund_);
        // }
        if (encryption_ != address(0)) {
            ENCRYPTION_STORAGE = I_EncryptionStorage(encryption_);
        }
        if (box_status_ != address(0)) {
            BOX_STATUS = box_status_;
        }
        if (dao_ != address(0)) {
            DAO = dao_;
        }
        
    }

    // ==========================================================================================================
    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);

        // string memory network_ = _baseURI();
        string memory tokenURI_ = NFTBOX[tokenId]._tokenURI;

        return string(abi.encodePacked(_network, tokenURI_, _uriSuffix));
    }

    // function _baseURI() internal view returns (string memory) {
    //     return _network;
    // }

    function setNetwork(string calldata network_, string calldata uri_) public onlyAdmin {
        _network = network_;
        _uriSuffix = uri_;
    }

    function setLogoURI(string calldata logoURI_) public onlyAdmin {
        _logoURI = logoURI_;
    }

    function logoURI() public view returns (string memory) {
        return _logoURI;
    }

    // ==========================================================================================================
    //                                               Blacklist Functions
    // ==========================================================================================================

    function addBlackTokenId(uint256 tokenId_) public onlyAdminDAO {
        if (_ownerOf(tokenId_) == address(0)) revert TokenNotExists();
        _blackTokenIds[tokenId_] = true;
        unchecked {
            _blackSupply += 1;
        }
    }

    function removeBlackTokenId(uint256 tokenId_) public onlyAdminDAO {
        if (_ownerOf(tokenId_) == address(0)) revert TokenNotExists();
        if (!_blackTokenIds[tokenId_]) revert BlackTokenIdNotExist();
        _blackTokenIds[tokenId_] = false;
        _blackSupply -= 1;
    }

    //==================================================================================================

    function isBlackTokenId(uint256 tokenId_) public view returns (bool) {
        return _blackTokenIds[tokenId_];
    }

    //==================================================================================================
    //                                      TODO  Get Info Functions
    //==================================================================================================

    function getStatus(uint256 tokenId_) public view returns (Status) {
        return NFTBOX[tokenId_]._status;
    }

    function setStatus(uint256 tokenId_, Status status_) external{
        if (msg.sender != BOX_STATUS) revert InvalidContractCaller();
        // if (_blackTokenIds[tokenId_]) revert Blacklisted();
        NFTBOX[tokenId_]._status = status_;
    }

    function getPrice(uint256 tokenId_) public view returns (uint256 ) {
        return NFTBOX[tokenId_]._price;
    }

    function setPrice(uint256 tokenId_, uint256 price_) external {
        if (msg.sender != CONFI_FEE && msg.sender != BOX_STATUS) revert InvalidContractCaller();
        if (_blackTokenIds[tokenId_]) revert Blacklisted();
        NFTBOX[tokenId_]._price = price_;
    }

    function getDeadline(uint256 tokenId_) public view returns (uint256) {
        return NFTBOX[tokenId_]._deadline;
    }

    function setDeadline(uint256 tokenId_, uint256 deadline_) external {
        if (msg.sender != CONFI_FEE && msg.sender != BOX_STATUS) revert InvalidContractCaller();
        // if (_blackTokenIds[tokenId_]) revert Blacklisted();
        NFTBOX[tokenId_]._deadline = deadline_;
    }

    // ==========================================================================================================

    function getBoxInfo(uint256 tokenId_) public view returns (
        string memory, 
        string memory, 
        string memory, 
        string memory, 
        uint256, 
        uint256, 
        Status
    ) {
        if (_blackTokenIds[tokenId_]) revert Blacklisted();
        
        return (
            NFTBOX[tokenId_]._infoCID,
            NFTBOX[tokenId_]._tokenURI,
            NFTBOX[tokenId_]._fileCID,
            NFTBOX[tokenId_]._password,
            NFTBOX[tokenId_]._price,
            NFTBOX[tokenId_]._deadline,
            NFTBOX[tokenId_]._status
        );
    }

    // ==========================================================================================================
    //                                      TODO   Functions
    // ==========================================================================================================

    function minterOf(uint256 tokenId_) public view returns (address) {
        return _minter[tokenId_];
    }

    function totalSupply() public view returns (uint256) {
        return _nextTokenId;
    } 

    function blackSupply() public view returns (uint256) {
        return _blackSupply;
    }

    // ==========================================================================================================
    //                                                 TODO  FilePasswHash Functions
    // ==========================================================================================================
    
    function publicMinter(uint256 tokenId_, string calldata fileCID_, string calldata password_) public {
        if (msg.sender != _minter[tokenId_]) revert InvalidCaller();
        if (NFTBOX[tokenId_]._status != Status.Storing) revert InvalidStatus();
        _setCidPassword(tokenId_, fileCID_, password_);
    }

    function _setCidPassword(uint256 tokenId_, string memory fileCID_, string memory password_) internal {
        if (_blackTokenIds[tokenId_]) revert Blacklisted();
        
        NFTBOX[tokenId_]._status = Status.Published;
        NFTBOX[tokenId_]._fileCID = fileCID_;
        NFTBOX[tokenId_]._password = password_;

        emit Public(tokenId_);
    } 

    function setCidPassword(uint256 tokenId_, string memory fileCID_, string memory password_) external {
        if (msg.sender != BOX_STATUS ) revert InvalidContractCaller();
        
        _setCidPassword(tokenId_, fileCID_, password_);
    }

    // ==========================================================================================================
    //                                                 TODO  mint Functions
    // ==========================================================================================================
    
    function _setBoxInfo(
        uint256 tokenId_, 
        string memory infoURI_, 
        string memory tokenURI_, 
        Status status_
    ) internal{

        _safeMint(msg.sender, tokenId_, "");
        NFTBOX[tokenId_]._infoCID = infoURI_;
        NFTBOX[tokenId_]._tokenURI = tokenURI_;
        // NFTBOX[tokenId_]._price = price_;
        NFTBOX[tokenId_]._status = status_;
        _minter[tokenId_] = msg.sender;
    }

    // ==========================================================================================================
    function mint(
        string calldata infoURI_,
        string calldata tokenURI_
    ) public returns(uint256){
        if (bytes(infoURI_).length == 0 || bytes(tokenURI_).length == 0) revert EmptyTokenInfo();
        
        uint256 tokenId_ = _nextTokenId;
        _setBoxInfo(tokenId_, infoURI_, tokenURI_, Status.Storing);
        // NFTBOX[tokenId_]._deadline = block.timestamp + 7 days; // 365----7

        unchecked {
            _nextTokenId++;
        }
        return tokenId_;
    }

    function mintPublic(
        string calldata infoURI_,
        string calldata tokenURI_,
        string calldata fileCID_
    ) public {
        // if (bytes(password_).length == 0) revert EmptyPassword();
        if (bytes(infoURI_).length == 0 || bytes(tokenURI_).length == 0) revert EmptyTokenInfo();
        if (bytes(fileCID_).length == 0) revert EmptyFileInfo();

        uint256 tokenId_ = _nextTokenId;
        _setBoxInfo(tokenId_, infoURI_, tokenURI_, Status.Published );
        _setCidPassword(tokenId_, fileCID_, '');
        // NFTBOX[tokenId_]._deadline = block.timestamp; 
        unchecked {
            _nextTokenId++;
        }
        emit Public(tokenId_);
    }

    // ==========================================================================================================
    //                                             burn Function
    // ==========================================================================================================

    // function burn(uint256 tokenId_) public{
    //     if ( getStatus(tokenId_) != Status.Published ) revert InvalidStatus();
    //     if (NFTBOX[tokenId_]._deadline + 90 days > block.timestamp) revert InPublicDeadline();  
    //     _burn(tokenId_);
    //     _blackTokenIds[tokenId_] = true;
    //     NFTBOX[tokenId_]._infoCID = '';
    //     NFTBOX[tokenId_]._tokenURI = '';
    //     NFTBOX[tokenId_]._fileCID = '';
    //     NFTBOX[tokenId_]._password = '';
    // }

    // ==========================================================================================================
    //                                                 override Functions
    // ==========================================================================================================

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(address from, address to, uint256 tokenId) public override {
        if (_blackTokenIds[tokenId]) revert Blacklisted();
        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        // Setting an "auth" arguments enables the `_isAuthorized` check which verifies that the token exists
        // (from != 0). Therefore, it is not needed to verify that the return value is not 0 here.
        address previousOwner = _update(to, tokenId, _msgSender());
        if (previousOwner != from) {
            revert ERC721IncorrectOwner(from, tokenId, previousOwner);
        }
    }
    
    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public override {
        if (_blackTokenIds[tokenId]) revert Blacklisted();
        _approve(to, tokenId, _msgSender());
    }
    // ==========================================================================================================

}