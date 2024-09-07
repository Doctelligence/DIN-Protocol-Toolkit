// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IntelligenceProtocol.sol";
import "./AggregatorManagement.sol";
import "./EvaluatorRegistry.sol";
import "./RewardDistribution.sol";
import "./StakeNFT.sol";
import "./HarbergerAuction.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract DINProtocol is ReentrancyGuard {
    DINToken public rewardToken;
    StakeNFT public stakeNFT;
    IntelligenceProtocol public intelligenceProtocol;
    AggregatorManagement public aggregatorManagement;
    EvaluatorRegistry public evaluatorRegistry;
    RewardDistribution public rewardDistribution;
    HarbergerAuction public harbergerAuction;

    uint256 public currentRound;
    address public modelOwner;
    bool public trainingComplete;

    event RoundStarted(uint256 roundNumber);
    event RoundCompleted(uint256 roundNumber);
    event TrainingCompleted(string finalModelCID);

    constructor(
        address _intelligenceProtocol,
        address _aggregatorManagement,
        address _evaluatorRegistry,
        address _rewardDistribution,
        address _stakeNFT,
        address _harbergerAuction,
        address _rewardToken
    ) {
        intelligenceProtocol = IntelligenceProtocol(_intelligenceProtocol);
        aggregatorManagement = AggregatorManagement(_aggregatorManagement);
        evaluatorRegistry = EvaluatorRegistry(_evaluatorRegistry);
        rewardDistribution = RewardDistribution(_rewardDistribution);
        stakeNFT = StakeNFT(_stakeNFT);
        harbergerAuction = HarbergerAuction(_harbergerAuction);
        rewardToken = DINToken(_rewardToken);
        currentRound = 1;
    }

    function registerParticipant() external {
        evaluatorRegistry.registerParticipant();
    }

    function registerEvaluator(uint256 stakeId) external {
        require(stakeNFT.ownerOf(stakeId) == msg.sender, "Must own the stake NFT");
        evaluatorRegistry.registerEvaluator(stakeId);
    }

    function submitModelUpdate(string memory modelCID) external {
        require(evaluatorRegistry.participants(msg.sender), "Only registered participants can submit updates");
        intelligenceProtocol.submitModelUpdate(modelCID);
        uint256 subgroupId = aggregatorManagement.assignParticipantToSubgroup(msg.sender);
        bytes32 modelHash = keccak256(abi.encodePacked(modelCID));
        aggregatorManagement.submitModelHash(currentRound, subgroupId, modelHash);
    }

    function submitEvaluation(bytes32 evaluationHash, bytes32 zkpHash) external {
        require(evaluatorRegistry.evaluatorStakeIds(msg.sender) != 0, "Only registered evaluators can submit evaluations");
        evaluatorRegistry.submitEvaluation(currentRound, evaluationHash);
        evaluatorRegistry.submitZKP(currentRound, zkpHash);

        // Update last tax payment in the EvaluatorStaking contract
        stakeNFT.updateLastTaxPayment(evaluatorRegistry.evaluatorStakeIds(msg.sender));
    }

    function aggregateAndStartNewRound() external onlyModelOwner {
        require(!trainingComplete, "Training is already complete");

        for (uint256 i = 0; i < aggregatorManagement.numSubgroups(); i++) {
            bytes32 aggregatedHash = aggregatorManagement.getAggregatedModelHash(currentRound, i);
            intelligenceProtocol.submitSubgroupAggregatedModel(i, bytes32ToString(aggregatedHash));
        }

        string memory masterAggregatedModelCID = aggregateSubgroupModels();
        intelligenceProtocol.submitMasterAggregatedModel(masterAggregatedModelCID);

        currentRound++;
        emit RoundCompleted(currentRound - 1);
        emit RoundStarted(currentRound);
    }

    function completeTraining(string memory finalModelCID) external onlyModelOwner {
        require(!trainingComplete, "Training is already complete");

        intelligenceProtocol.completeTraining(finalModelCID);
        trainingComplete = true;
        emit TrainingCompleted(finalModelCID);
    }

    function distributeRewards() external onlyModelOwner {
        require(trainingComplete, "Training must be complete before distributing rewards");
        uint256 rewardAmount = rewardToken.balanceOf(address(this));
        rewardDistribution.distributeRewards(currentRound - 1, rewardAmount);
    }

    function payTax(uint256 tokenId) external payable {
        harbergerAuction.payTax{value: msg.value}(tokenId);
    }

    function setStakeForSale(uint256 tokenId, bool forSale, uint256 price) external {
        harbergerAuction.setForSale(tokenId, forSale, price);
    }

    function purchaseStake(uint256 tokenId) external payable {
        harbergerAuction.purchaseStake{value: msg.value}(tokenId);
    }

    function bytes32ToString(bytes32 _bytes32) internal pure returns (string memory) {
        uint8 i = 0;
        while (i < 32 && _bytes32[i] != 0) {
            i++;
        }
        bytes memory bytesArray = new bytes(i);
        for (i = 0; i < 32 && _bytes32[i] != 0; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return string(bytesArray);
    }

    function aggregateSubgroupModels() internal view returns (string memory) {
        bytes memory aggregatedBytes;
        for (uint256 i = 0; i < aggregatorManagement.numSubgroups(); i++) {
            bytes32 subgroupHash = aggregatorManagement.getAggregatedModelHash(currentRound, i);
            aggregatedBytes = abi.encodePacked(aggregatedBytes, subgroupHash);
        }
        return bytes32ToString(keccak256(aggregatedBytes));
    }
}
