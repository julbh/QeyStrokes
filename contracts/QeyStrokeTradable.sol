// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./library/ERC1155.sol";
import "./library/ERC1155MintBurn.sol";
import "./library/ERC1155Metadata.sol";
import "./Whitelisted.sol";

contract OwnableDelegateProxy {}

contract ProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
}

/**
 * @title QeyStrokeTradable
 * FantomArtTradable - ERC1155 contract that whitelists an operator address, 
 * has mint functionality, and supports useful standards from OpenZeppelin,
  like _exists(), name(), symbol(), and totalSupply()
 */
contract QeyStrokeTradable is
    ERC1155,
    ERC1155MintBurn,
    ERC1155Metadata,
    Ownable
{
    uint256 private _currentTokenID = 0;

    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;

    mapping(uint256 => address) public creators;

    // token id => Parcel: 0~3, G: 4~9 total 10
    mapping(uint256 => uint8) public catogories;

    // mapping(uint256 => bool) public mintedTokens;

    Whitelist.List private _list;
    
    // availability of burning
    bool burnEnabled;
    // Number of remaining tokens
    uint256 curWhiteTokenCount;
    // 1261
    uint256 parcelSize;
    // Array of remaining tokens
    uint256[] whiteTokens;
    
    // Contract name
    string public name;
    // Contract symbol
    string public symbol;
    // Platform fee
    uint256 public platformFee;
    // Platform fee receipient
    address payable public feeReceipient;
    // Fantom Marketplace contract
    address marketplace;

    //*******************  WhiteList start***********************/

    modifier onlyWhitelisted() {
        require(Whitelist.check(_list, msg.sender) > 0);
        _;
    }

    event WhitelistEvent(address _addr, uint8 _degree);

    //*******************  WhiteList end***********************/


    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _platformFee,
        address payable _feeReceipient,
        address _marketplace
        // address _bundleMarketplace
    ) public {
        name = _name;
        symbol = _symbol;
        platformFee = _platformFee;
        feeReceipient = _feeReceipient;
        marketplace = _marketplace;
        // whiteMax = 3939;
        burnEnabled = false;
        curWhiteTokenCount = 3939;
        // total = 5000;
        parcelSize = 1261;
        initWhiteTokens();
    }

    function uri(uint256 _id) public view override returns (string memory) {
        require(_exists(_id), "ERC721Tradable#uri: NONEXISTENT_TOKEN");
        return _tokenURIs[_id];
    }

    /**
     * @dev Returns the total quantity for a token ID
     * @param _id uint256 ID of the token to query
     * @return amount of token in existence
     */
    // function totalSupply(uint256 _id) public view returns (uint256) {
    //     return tokenSupply[_id];
    // }

    /**
     * @dev Creates a new token type and assigns _supply to an address
     * @param _to owner address of the new token
     * @param _supply Optional amount to supply the first owner
     * @param _uri Optional URI for this token type
     */
    function mint(
        address _to,
        uint256 _supply,      // must be 1
        string calldata _uri
    ) external payable {
        require(msg.value >= platformFee, "Insufficient funds to mint.");
        require(whiteDegree(_to) > 0, "Insufficient degree to mint.");

        require( _setTokenId(_to) );

        uint256 _id = _currentTokenID;
        _setTokenURI(_id, _uri);

        if (bytes(_uri).length > 0) {
            emit URI(_uri, _id);
        }

        _mint(_to, _id, _supply, bytes(""));

        creators[_id] = msg.sender;
        catogories[_id] = uint8(_id / parcelSize);
        // tokenSupply[_id] = _supply;

        // Send FTM fee to fee recipient
        (bool success, ) = feeReceipient.call{value: msg.value}("");
        require(success, "Transfer failed");
    }

    function burn123(address _from, uint256 _parcelId1, uint256 _parcelId2, uint256 _parcelId3) public {
        require(burnEnabled, "No burning is enabled.");
        require(_parcelId1 > parcelSize);
        require(_parcelId2 > parcelSize * 2);  
        require(_parcelId3 > parcelSize * 3);
        require(creators[_parcelId1] == _from);
        require(creators[_parcelId2] == _from);
        require(creators[_parcelId3] == _from);

        _burn(_from, _parcelId1, 1);
        _burn(_from, _parcelId2, 1);
        _burn(_from, _parcelId3, 1);

        delete creators[_parcelId1];
        delete creators[_parcelId2];
        delete creators[_parcelId3];
    }



    function getCurrentTokenID() public view returns (uint256) {
        return _currentTokenID;
    }

    function getCatogory(uint256 _id) public view returns (uint8) {
        return catogories[_id];
    }

    /**
     * Override isApprovedForAll to whitelist Fantom contracts to enable gas-less listings.
     */
    function isApprovedForAll(address _owner, address _operator)
        public
        view
        override
        returns (bool isOperator)
    {
        // Whitelist Fantom marketplace, bundle marketplace contracts for easy trading.
        if (marketplace == _operator) {
            return true;
        }

        return ERC1155.isApprovedForAll(_owner, _operator);
    }

    /**
     * @dev Returns whether the specified token exists by checking to see if it has a creator
     * @param _id uint256 ID of the token to query the existence of
     * @return bool whether the token exists
     */
    function _exists(uint256 _id) public view returns (bool) {
        return creators[_id] != address(0);
    }

    /**
     * @dev calculates the next token ID based on value of _currentTokenID after post minting
     * @return uint256 for the next token ID
     */
    function _getNextTokenID() private view returns (uint256) {
        return _currentTokenID.add(1);
    }

    /**
    * @dev increments the value of _currentTokenID
    */
    function _incrementTokenTypeId() private  {
        _currentTokenID++;
    }

    /**
     * @dev set the value of _currentTokenID when post minting
     */
    function _setTokenId(address _addr) private returns(bool) {
        if(curWhiteTokenCount == 0) return false;
        
        uint256 _index = uint256(uint(keccak256(abi.encodePacked(now, _addr))) % curWhiteTokenCount + 1);
        _currentTokenID = whiteTokens[_index];
        // mintedTokens[_currentTokenID] = true;
        aryRemoveEle(_index);
        if(whiteTokens.length == 0) burnEnabled = true;
        return true;
    }

    /**
     * @dev Internal function to set the token URI for a given token.
     * Reverts if the token ID does not exist.
     * @param _id uint256 ID of the token to set its URI
     * @param _uri string URI to assign
     */
    function _setTokenURI(uint256 _id, string memory _uri) internal {
        require(_exists(_id), "_setTokenURI: Token should exist");
        _tokenURIs[_id] = _uri;
    }

    //*******************  WhiteList start  ***********************/

    function addWhitelist(address _addr, uint8 _degree)
    public
    {
        Whitelist.add(_list, _addr, _degree);
        emit WhitelistEvent(_addr, _degree);
    }

    function subWhiteList(address _addr, uint8 _degree)
        public
    {
        Whitelist.sub(_list, _addr, _degree);
        emit WhitelistEvent(_addr, _degree);
    }
    
    function whiteDegree(address _addr)
    public
    view
    returns (uint8)
    {
        return Whitelist.check(_list, _addr);
    }

    //*******************  WhiteList end  ***********************/

    function initWhiteTokens() internal {
        for (uint256 i = 0; i<curWhiteTokenCount; i++) {
            whiteTokens.push(i + 1);
        }
    }

    function aryRemoveEle(uint256 index) internal {
        if (index >= curWhiteTokenCount) return;

        for (uint i = index; i<whiteTokens.length-1; i++){
            whiteTokens[i] = whiteTokens[i+1];
        }
        whiteTokens.pop();
        curWhiteTokenCount --;
    }
}
