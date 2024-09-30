// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract LaunchPadFactory {
    address public owner;
    uint public totalLaunchPads = 1;
    uint public listingFee = 0.0006 ether;
    mapping(address => bool) public whitelistedAddresses;
    mapping(uint => PadDetails) public LaunchPads;
    mapping(address => bool) public Admins;

    struct PadDetails {
        string name;
        address creator;
        uint timeCreated;
        address padAddress;
    }

    event LaunchPadCreated(address _launchpad, address _seller);

    constructor(address _DAOAddress) {
        owner = _DAOAddress;
        Admins[msg.sender] = true;
    }

    modifier onlyOwner() {
        require(Admins[msg.sender], "Only Admins can call this function");
        _;
    }

    function setListingFee(uint _fee) external onlyOwner {
        require(_fee != 0, "Can't set fee to zero");
        listingFee = _fee;
    }

    function whitelistAddress(address _address) public onlyOwner {
        require(_address != address(0), "Can't whitelist address zero");
        whitelistedAddresses[_address] = true;
    }

    function removeAdmin(address _address) external onlyOwner {
        require(_address != address(0), "Can't whitelist address zero");
        Admins[_address] = false;
    }

    function setAdmin(address _address) external onlyOwner {
        require(_address != address(0), "Can't whitelist address zero");
        Admins[_address] = true;
    }

    function createLaunchPad(
        string memory _name,
        string memory symbol,
        string memory uri
    ) external payable returns (address _launchpad) {
        require(
            whitelistedAddresses[msg.sender],
            "Only whitelisted addresses can create a launchpad"
        );
        require(msg.value >= listingFee, "Fee not up to listing fee");

        LaunchPad _newlaunchpad = new LaunchPad(_name, symbol, msg.sender, uri);
        _launchpad = address(_newlaunchpad);
        PadDetails storage _PD = LaunchPads[totalLaunchPads];
        _PD.name = _name;
        _PD.creator = msg.sender;
        _PD.timeCreated = block.timestamp;
        _PD.padAddress = _launchpad;
        totalLaunchPads++;
        whitelistedAddresses[msg.sender] = false;
        emit LaunchPadCreated(_launchpad, msg.sender);
    }

    function withdraw() external onlyOwner returns (bool success) {
        (success, ) = payable(owner).call{value: address(this).balance}("");
    }

    receive() external payable {}
}

contract LaunchPad is ERC721URIStorage {
    address public owner;
    uint public duration;
    uint public totalNftsForSale;
    uint public amtRaised;
    uint public price;
    uint256 public startTime;
    uint256 public endTime;
    uint256 public totalAmountNeeded;
    uint public mintedTokenId;
    address[] public subscribers;
    mapping(address => uint) public NFTperAddr;
    uint256 public numberOfSubscribers = 1;
    uint256 public totalNFTCommitment;
    string public baseURI;

    mapping(address => uint) public subscriberIndex; // Get the index of a suscriber

    event LaunchPadStarted(uint _startTime);
    event LaunchPadEnded(uint _endTime);

    constructor(
        string memory _name,
        string memory _symbol,
        address _owner,
        string memory _uri
    ) ERC721(_name, _symbol) {
        owner = _owner;
        baseURI = _uri;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    function startLaunchPad(
        uint256 _duration,
        uint _nftprice,
        uint256 _totalAmountNeeded
    ) external onlyOwner {
        require(_duration != 0, "Duration can't be zero");
        require(duration == 0, "Launchpad already started");

        price = _nftprice;
        duration = _duration;
        startTime = block.timestamp;
        endTime = block.timestamp + duration;
        totalNftsForSale = (_totalAmountNeeded / _nftprice) + 1;
        totalAmountNeeded = _totalAmountNeeded;

        emit LaunchPadStarted(block.timestamp);
    }

    function depositETH(
        uint256 _amtofNFT
    ) external payable returns (bool success) {
        require(block.timestamp < endTime, "Campaign ended");
        require(block.timestamp > startTime, "Campaign not started yet");
        require(
            _amtofNFT < totalNftsForSale,
            "You can't buy more NFTs than is up for sale"
        );
        require(amtRaised <= totalAmountNeeded, "Maximum Amount Reached");
        require(
            totalNFTCommitment <= totalNftsForSale,
            "All NFTs have been booked"
        );
        require(
            msg.value == _amtofNFT * price,
            "Send appropriate value for NFT"
        );
        NFTperAddr[msg.sender] += _amtofNFT;
        amtRaised += msg.value;
        subscribers.push(msg.sender);
        subscriberIndex[msg.sender] = numberOfSubscribers;
        numberOfSubscribers++;
        totalNFTCommitment += _amtofNFT;
        success = true;
    }

    function withdrawNFT() public returns (bool success) {
        uint _amtofNFT = NFTperAddr[msg.sender];
        require(block.timestamp > endTime, "campaign not yet ended");
        require(_amtofNFT > 0, "You did not suscribe");

        for (uint i = 1; i <= _amtofNFT; i++) {
            // Add to Constructor
            _mint(msg.sender, mintedTokenId);
            mintedTokenId++;
        }
        NFTperAddr[msg.sender] = 0;
        success = true;
    }

    function transferLeftoverNFT(
        address recipient
    ) external onlyOwner returns (bool success) {
        require(block.timestamp > endTime, "LaunchPad has not ended");

        require(
            totalNFTCommitment < totalNftsForSale,
            "All NFTs has been minted"
        );

        uint totalLeft = totalNftsForSale - totalNFTCommitment;

        for (uint i = 0; i < totalLeft; i++) {
            _mint(recipient, mintedTokenId);
            mintedTokenId++;
        }

        success = true;
    }

    // To enable the contract send out ether... to be done by only the launchpad owner
    function withdrawETH(
        address payable inputAddress,
        uint amount
    ) external onlyOwner {
        require(inputAddress != address(0), "Can't send ether to address zero");
        require(
            amount <= address(this).balance,
            "Amount not available for withdrawal"
        );
        (bool success, ) = inputAddress.call{value: amount}("");
        require(success, "This transaction has failed");
    }

    function _baseURI()
        internal
        view
        virtual
        override(ERC721)
        returns (string memory)
    {
        return baseURI;
    }

    function withdraw() external onlyOwner returns (bool success) {
        (success, ) = payable(owner).call{value: address(this).balance}("");
    }

    receive() external payable {}
}
