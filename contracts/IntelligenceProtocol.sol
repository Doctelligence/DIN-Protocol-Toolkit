// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./EvaluatorRegistry.sol";
import "./RewardDistribution.sol";
import "./AggregatorManagement.sol";
import "./EvaluatorStaking.sol";

contract IntelligenceProtocol is EvaluatorRegistry, RewardDistribution, AggregatorManagement {
    EvaluatorStaking public stakingContract;
    string public genesisModelCID;
    uint256 public roundNumber;
    string public encryptedControlDatasetCID;
    bool public trainingComplete;
    
    mapping(uint256 => mapping(address => string)) public participantModelCIDs;
    mapping(uint256 => mapping(uint256 => string)) public subgroupAggregatedModelCIDs;
    mapping(uint256 => string) public masterAggregatedModelCIDs;
    
    event NewRound(uint256 roundNumber, string globalModelCID);
    event ParticipantUpdate(address participant, uint256 roundNumber, string modelCID);
    event SubgroupAggregationComplete(uint256 roundNumber, uint256 subgroupId, string aggregatedModelCID);
    event MasterAggregationComplete(uint256 roundNumber, string masterAggregatedModelCID);
    event TrainingComplete(string finalGlobalModelCID);
    event ControlDatasetUploaded(string encryptedControlDatasetCID);
    
    constructor(
        uint256 _numSubgroups, 
        uint256 _evaluatorRatio, 
        address _stakingContractAddress,
        uint256 _minimumStake
    ) AggregatorManagement(_numSubgroups, _evaluatorRatio) {
        stakingContract = EvaluatorStaking(_stakingContractAddress);
        minimumStake = _minimumStake;
        modelOwner = msg.sender;
        roundNumber = 0;
    }
    
    function deployGenesisModel(string memory _genesisModelCID) external onlyModelOwner {
        genesisModelCID = _genesisModelCID;
        emit NewRound(roundNumber, _genesisModelCID);
    }
    
    function submitModelUpdate(string memory _modelCID) external onlyParticipant {
        require(!trainingComplete, "Training is already complete");
        participantModelCIDs[roundNumber][msg.sender] = _modelCID;
        emit ParticipantUpdate(msg.sender, roundNumber, _modelCID);
    }
    
    function submitSubgroupAggregatedModel(uint256 _subgroupId, string memory _aggregatedModelCID) external onlyAggregator {
        subgroupAggregatedModelCIDs[roundNumber][_subgroupId] = _aggregatedModelCID;
        emit SubgroupAggregationComplete(roundNumber, _subgroupId, _aggregatedModelCID);
    }
    
    function submitMasterAggregatedModel(string memory _masterAggregatedModelCID) external onlyModelOwner {
        masterAggregatedModelCIDs[roundNumber] = _masterAggregatedModelCID;
        emit MasterAggregationComplete(roundNumber, _masterAggregatedModelCID);
    }
    
    function startNewRound() external onlyModelOwner {
        require(!trainingComplete, "Training is already complete");
        roundNumber++;
        emit NewRound(roundNumber, masterAggregatedModelCIDs[roundNumber - 1]);
    }
    
    function uploadControlDataset(string memory _encryptedControlDatasetCID) external onlyModelOwner {
        encryptedControlDatasetCID = _encryptedControlDatasetCID;
        emit ControlDatasetUploaded(_encryptedControlDatasetCID);
    }
    
    function completeTraining(string memory _finalGlobalModelCID) external onlyModelOwner {
        require(encryptedControlDatasetCID != "", "Control dataset must be uploaded before completing training");
        trainingComplete = true;
        masterAggregatedModelCIDs[roundNumber] = _finalGlobalModelCID;
        emit TrainingComplete(_finalGlobalModelCID);
    }
    
    function registerEvaluator(uint256 stakeId) external {
        require(stakingContract.ownerOf(stakeId) == msg.sender, "Must own the stake NFT");
        require(stakingContract.getStakedAmount(stakeId) >= minimumStake, "Insufficient stake");
        super.registerEvaluator(stakeId);
    }
    
    function unregisterEvaluator() external {
        require(evaluatorStakeIds[msg.sender] != 0, "Not registered as an evaluator");
        delete evaluatorStakeIds[msg.sender];
    }
}
