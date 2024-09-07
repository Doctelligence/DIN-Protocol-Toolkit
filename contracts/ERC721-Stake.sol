// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract EvaluatorNFT is ERC721, ReentrancyGuard, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    struct NFTInfo {
        uint256 declaredValue;
        uint256 lastTaxPayment;
        bool forSale;
        uint256 salePrice;
    }

    mapping(uint256 => NFTInfo) public nfts;

    uint256 public constant TAX_RATE = 5; // 5% annual tax rate
    uint256 public constant TAX_PERIOD = 90 days; // Quarterly tax period
    uint256 public minimumValue;

    event NFTMinted(uint256 tokenId, address owner, uint256 declaredValue);
    event NFTUpdated(uint256 tokenId, uint256 newDeclaredValue);
    event TaxPaid(uint256 tokenId, uint256 taxAmount);
    event NFTForSale(uint256 tokenId, bool forSale, uint256 price);
    event NFTPurchased(uint256 tokenId, address newOwner, uint256 price);

    constructor(string memory name, string memory symbol, uint256 _minimumValue) ERC721(name, symbol) {
        minimumValue = _minimumValue;
    }

    function mintNFT(uint256 declaredValue) external payable nonReentrant {
        require(msg.value >= declaredValue, "Insufficient payment");
        require(declaredValue >= minimumValue, "Declared value below minimum");

        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        _safeMint(msg.sender, newTokenId);

        nfts[newTokenId] = NFTInfo({
            declaredValue: declaredValue,
            lastTaxPayment: block.timestamp,
            forSale: false,
            salePrice: 0
        });

        emit NFTMinted(newTokenId, msg.sender, declaredValue);
    }

    function updateDeclaredValue(uint256 tokenId, uint256 newDeclaredValue) external {
        require(ownerOf(tokenId) == msg.sender, "Not the NFT owner");
        require(newDeclaredValue >= minimumValue, "Declared value below minimum");
        nfts[tokenId].declaredValue = newDeclaredValue;
        emit NFTUpdated(tokenId, newDeclaredValue);
    }

    function payTax(uint256 tokenId) external payable {
        require(ownerOf(tokenId) == msg.sender, "Not the NFT owner");
        uint256 taxOwed = calculateTaxOwed(tokenId);
        require(msg.value >= taxOwed, "Insufficient tax payment");
        nfts[tokenId].lastTaxPayment = block.timestamp;
        emit TaxPaid(tokenId, taxOwed);
    }

    function calculateTaxOwed(uint256 tokenId) public view returns (uint256) {
        uint256 timeElapsed = block.timestamp - nfts[tokenId].lastTaxPayment;
        uint256 periods = timeElapsed / TAX_PERIOD;
        return (nfts[tokenId].declaredValue * TAX_RATE * periods) / 100 / 4; // Quarterly tax
    }

    function setForSale(uint256 tokenId, bool forSale, uint256 price) external {
        require(ownerOf(tokenId) == msg.sender, "Not the NFT owner");
        nfts[tokenId].forSale = forSale;
        nfts[tokenId].salePrice = price;
        emit NFTForSale(tokenId, forSale, price);
    }

    function purchaseNFT(uint256 tokenId) external payable nonReentrant {
        require(nfts[tokenId].forSale, "NFT not for sale");
        require(msg.value >= nfts[tokenId].salePrice, "Insufficient payment");

        address seller = ownerOf(tokenId);
        _transfer(seller, msg.sender, tokenId);

        nfts[tokenId].forSale = false;
        nfts[tokenId].salePrice = 0;

        payable(seller).transfer(msg.value);

        emit NFTPurchased(tokenId, msg.sender, msg.value);
    }

    function getNFTInfo(uint256 tokenId) external view returns (uint256, uint256, bool, uint256) {
        return (
            nfts[tokenId].declaredValue,
            nfts[tokenId].lastTaxPayment,
            nfts[tokenId].forSale,
            nfts[tokenId].salePrice
        );
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        payable(owner()).transfer(balance);
    }
}
