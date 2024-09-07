// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

contract EvaluatorStaking is Initializable, ERC721Upgradeable, ReentrancyGuardUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private _tokenIds;

    struct StakeInfo {
        uint256 declaredValue;
        uint256 lastTaxPayment;
        bool forSale;
        uint256 salePrice;
    }

    mapping(uint256 => StakeInfo) public stakes;
    uint256 public minimumStake;
    address public harbergerAuction;

    event StakeCreated(uint256 tokenId, address owner, uint256 declaredValue);
    event StakeUpdated(uint256 tokenId, uint256 newDeclaredValue);
    event StakeForSale(uint256 tokenId, bool forSale, uint256 price);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(string memory name, string memory symbol, uint256 _minimumStake) public initializer {
        __ERC721_init(name, symbol);
        __ReentrancyGuard_init();
        __Ownable_init();
        __UUPSUpgradeable_init();

        minimumStake = _minimumStake;
    }

    function setHarbergerAuction(address _harbergerAuction) external onlyOwner {
        harbergerAuction = _harbergerAuction;
    }

    function createStake(uint256 declaredValue) external payable nonReentrant {
        require(msg.value >= declaredValue, "Insufficient stake amount");
        require(declaredValue >= minimumStake, "Declared value below minimum");

        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        _safeMint(msg.sender, newTokenId);

        stakes[newTokenId] = StakeInfo({
            declaredValue: declaredValue,
            lastTaxPayment: block.timestamp,
            forSale: false,
            salePrice: 0
        });

        emit StakeCreated(newTokenId, msg.sender, declaredValue);
    }

    function updateDeclaredValue(uint256 tokenId, uint256 newDeclaredValue) external {
        require(ownerOf(tokenId) == msg.sender, "Not the stake owner");
        require(newDeclaredValue >= minimumStake, "Declared value below minimum");
        stakes[tokenId].declaredValue = newDeclaredValue;
        emit StakeUpdated(tokenId, newDeclaredValue);
    }

    function updateLastTaxPayment(uint256 tokenId) external {
        require(msg.sender == harbergerAuction, "Only HarbergerAuction can update tax payment");
        stakes[tokenId].lastTaxPayment = block.timestamp;
    }

    function setForSale(uint256 tokenId, bool forSale, uint256 price) external {
        require(msg.sender == harbergerAuction, "Only HarbergerAuction can set for sale");
        stakes[tokenId].forSale = forSale;
        stakes[tokenId].salePrice = price;
        emit StakeForSale(tokenId, forSale, price);
    }

    function getStakePrice(uint256 tokenId) external view returns (uint256, bool) {
        return (stakes[tokenId].salePrice, stakes[tokenId].forSale);
    }

    function getStakeInfo(uint256 tokenId) external view returns (uint256, uint256) {
        return (stakes[tokenId].declaredValue, stakes[tokenId].lastTaxPayment);
    }

    function getStakedAmount(uint256 tokenId) external view returns (uint256) {
        return stakes[tokenId].declaredValue;
    }

    // New function to check if an account has any staked tokens
    function isStaked(address account) external view returns (bool) {
        return balanceOf(account) > 0;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
