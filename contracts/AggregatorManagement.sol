
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract AggregatorManagement is ReentrancyGuard {
    uint256 public numSubgroups;
    uint256 public evaluatorRatio;
    uint256 public aggregationThreshold;
    
    mapping(address => bool) public aggregators;
    mapping(uint256 => address[]) public subgroupParticipants;
    mapping(uint256 => address[]) public subgroupEvaluators;
    mapping(uint256 => mapping(uint256 => mapping(address => bytes32))) public subgroupModelHashes;
    mapping(uint256 => mapping(uint256 => uint256)) public subgroupAggregationCount;
    mapping(uint256 => mapping(uint256 => bytes32)) public subgroupAggregatedModelHashes;
    
    event SubgroupAssigned(address participant, uint256 subgroupId);
    event EvaluatorAssigned(address evaluator, uint256 subgroupId);
    event ModelHashSubmitted(address participant, uint256 roundNumber, uint256 subgroupId, bytes32 modelHash);
    event SubgroupAggregationComplete(uint256 roundNumber, uint256 subgroupId, bytes32 aggregatedModelHash);

    constructor(uint256 _numSubgroups, uint256 _evaluatorRatio, uint256 _aggregationThreshold) {
        numSubgroups = _numSubgroups;
        evaluatorRatio = _evaluatorRatio;
        aggregationThreshold = _aggregationThreshold;
    }

    modifier onlyAggregator() {
        require(aggregators[msg.sender], "Only aggregators can perform this action");
        _;
    }

    function registerAggregator(address _aggregator) external {
        // In a real implementation, this should be restricted to admin or governance
        aggregators[_aggregator] = true;
    }

    function assignParticipantToSubgroup(address _participant) internal returns (uint256) {
        uint256 subgroupId = uint256(keccak256(abi.encodePacked(_participant))) % numSubgroups;
        subgroupParticipants[subgroupId].push(_participant);
        emit SubgroupAssigned(_participant, subgroupId);
        return subgroupId;
    }

    function assignEvaluatorToSubgroup(address _evaluator) internal {
        uint256 subgroupId = uint256(keccak256(abi.encodePacked(_evaluator))) % numSubgroups;
        subgroupEvaluators[subgroupId].push(_evaluator);
        emit EvaluatorAssigned(_evaluator, subgroupId);
    }

    function submitModelHash(uint256 _roundNumber, uint256 _subgroupId, bytes32 _modelHash) external nonReentrant {
        require(isParticipantInSubgroup(msg.sender, _subgroupId), "Participant not in this subgroup");
        subgroupModelHashes[_roundNumber][_subgroupId][msg.sender] = _modelHash;
        subgroupAggregationCount[_roundNumber][_subgroupId]++;
        emit ModelHashSubmitted(msg.sender, _roundNumber, _subgroupId, _modelHash);

        if (subgroupAggregationCount[_roundNumber][_subgroupId] >= aggregationThreshold) {
            aggregateSubgroupModels(_roundNumber, _subgroupId);
        }
    }

    function aggregateSubgroupModels(uint256 _roundNumber, uint256 _subgroupId) internal {
        bytes32 aggregatedHash = calculateAggregatedHash(_roundNumber, _subgroupId);
        subgroupAggregatedModelHashes[_roundNumber][_subgroupId] = aggregatedHash;
        emit SubgroupAggregationComplete(_roundNumber, _subgroupId, aggregatedHash);
    }

    function calculateAggregatedHash(uint256 _roundNumber, uint256 _subgroupId) internal view returns (bytes32) {
        bytes32 aggregatedHash;
        for (uint256 i = 0; i < subgroupParticipants[_subgroupId].length; i++) {
            address participant = subgroupParticipants[_subgroupId][i];
            aggregatedHash ^= subgroupModelHashes[_roundNumber][_subgroupId][participant];
        }
        return aggregatedHash;
    }

    function isParticipantInSubgroup(address _participant, uint256 _subgroupId) public view returns (bool) {
        for (uint256 i = 0; i < subgroupParticipants[_subgroupId].length; i++) {
            if (subgroupParticipants[_subgroupId][i] == _participant) {
                return true;
            }
        }
        return false;
    }

    function getSubgroupParticipants(uint256 _subgroupId) external view returns (address[] memory) {
        return subgroupParticipants[_subgroupId];
    }

    function getSubgroupEvaluators(uint256 _subgroupId) external view returns (address[] memory) {
        return subgroupEvaluators[_subgroupId];
    }

    function updateEvaluatorRatio(uint256 _newRatio) external {
        // In a real implementation, this should be restricted to admin or governance
        evaluatorRatio = _newRatio;
    }

    function getAggregatedModelHash(uint256 _roundNumber, uint256 _subgroupId) external view returns (bytes32) {
        return subgroupAggregatedModelHashes[_roundNumber][_subgroupId];
    }
    function setAggregationThreshold(uint256 _newThreshold) external onlyOwner {
        aggregationThreshold = _newThreshold;
    }
}
