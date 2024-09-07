// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./EvaluatorStaking.sol";

contract HarbergerAuction is ReentrancyGuard, Ownable {
    EvaluatorStaking public stakingContract;
    uint256 public constant TAX_RATE = 5; // 5% annual tax rate
    uint256 public constant TAX_PERIOD = 90 days; // Quarterly tax period

    event TaxPaid(uint256 tokenId, uint256 amount);
    event StakeForSale(uint256 tokenId, bool forSale, uint256 price);
    event StakePurchased(uint256 tokenId, address newOwner, uint256 price);

    constructor(address _stakingContract) {
        stakingContract = EvaluatorStaking(_stakingContract);
    }

    function payTax(uint256 tokenId) external payable nonReentrant {
        require(stakingContract.ownerOf(tokenId) == msg.sender, "Not the stake owner");
        uint256 taxDue = calculateTaxDue(tokenId);
        require(msg.value >= taxDue, "Insufficient tax payment");

        // Update last tax payment timestamp
        stakingContract.updateLastTaxPayment(tokenId);

        emit TaxPaid(tokenId, taxDue);

        if (msg.value > taxDue) {
            payable(msg.sender).transfer(msg.value - taxDue);
        }
    }

    function calculateTaxDue(uint256 tokenId) public view returns (uint256) {
        (uint256 declaredValue, uint256 lastTaxPayment) = stakingContract.getStakeInfo(tokenId);
        uint256 timeSinceLastPayment = block.timestamp - lastTaxPayment;
        return (declaredValue * TAX_RATE * timeSinceLastPayment) / (365 days * 100);
    }

    function setForSale(uint256 tokenId, bool forSale, uint256 price) external {
        require(stakingContract.ownerOf(tokenId) == msg.sender, "Not the stake owner");
        stakingContract.setForSale(tokenId, forSale, price);
        emit StakeForSale(tokenId, forSale, price);
    }

    function purchaseStake(uint256 tokenId) external payable nonReentrant {
        (uint256 price, bool forSale) = stakingContract.getStakePrice(tokenId);
        require(forSale, "Stake not for sale");
        require(msg.value >= price, "Insufficient payment");

        address previousOwner = stakingContract.ownerOf(tokenId);
        stakingContract.transferFrom(previousOwner, msg.sender, tokenId);

        payable(previousOwner).transfer(price);
        stakingContract.setForSale(tokenId, false, 0);

        emit StakePurchased(tokenId, msg.sender, price);

        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }
    }

    function withdrawTaxes() external onlyOwner {
        uint256 balance = address(this).balance;
        payable(owner()).transfer(balance);
    }
}
