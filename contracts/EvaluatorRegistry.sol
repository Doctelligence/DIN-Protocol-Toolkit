// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./EvaluatorStaking.sol";

contract EvaluatorRegistry is ReentrancyGuard, Ownable {
    EvaluatorStaking public stakingContract;
    uint256 public constant SLASH_PERCENTAGE = 10; // 10% of stake, adjustable
    uint256 public minimumStake;

    mapping(address => bool) public participants;
    mapping(address => uint256) public evaluatorStakeIds;
    mapping(uint256 => mapping(address => bytes32)) public evaluationHashes;
    mapping(uint256 => mapping(address => bytes32)) public zkpHashes;
    mapping(uint256 => address[]) public roundEvaluators;

    event EvaluationSubmitted(address evaluator, uint256 roundNumber, bytes32 evaluationHash);
    event ZKPSubmitted(address evaluator, uint256 roundNumber, bytes32 zkpHash);
    event EvaluatorSlashed(address evaluator, uint256 amount);

    constructor(address _stakingContract, uint256 _minimumStake) {
        stakingContract = EvaluatorStaking(_stakingContract);
        minimumStake = _minimumStake;
    }

    modifier onlyParticipant() {
        require(participants[msg.sender], "Only registered participants can perform this action");
        _;
    }

    modifier onlyEvaluator() {
        require(evaluatorStakeIds[msg.sender] != 0, "Only evaluators can perform this action");
        _;
    }

    function registerParticipant() external {
        participants[msg.sender] = true;
    }

    function registerEvaluator(uint256 stakeId) external nonReentrant {
        require(stakingContract.ownerOf(stakeId) == msg.sender, "Must own the stake NFT");
        uint256 stakedAmount = stakingContract.getStakedAmount(stakeId);
        require(stakedAmount >= minimumStake, "Insufficient stake");
        evaluatorStakeIds[msg.sender] = stakeId;
    }

    function unregisterEvaluator() external nonReentrant {
        require(evaluatorStakeIds[msg.sender] != 0, "Not registered as an evaluator");
        delete evaluatorStakeIds[msg.sender];
    }

    function submitEvaluation(uint256 roundNumber, bytes32 evaluationHash) external onlyEvaluator {
        evaluationHashes[roundNumber][msg.sender] = evaluationHash;
        roundEvaluators[roundNumber].push(msg.sender);
        emit EvaluationSubmitted(msg.sender, roundNumber, evaluationHash);
    }

    function submitZKP(uint256 roundNumber, bytes32 zkpHash) external onlyEvaluator {
        zkpHashes[roundNumber][msg.sender] = zkpHash;
        emit ZKPSubmitted(msg.sender, roundNumber, zkpHash);
    }

    function verifyProtocolCompliance(uint256 roundNumber, address evaluator, bytes calldata proof) external {
        require(evaluatorStakeIds[evaluator] != 0, "Address is not an evaluator");
        
        bool compliant = verifyZKP(roundNumber, evaluator, proof);
        
        if (!compliant) {
            uint256 stakeId = evaluatorStakeIds[evaluator];
            uint256 stakeAmount = stakingContract.getStakedAmount(stakeId);
            uint256 slashAmount = (stakeAmount * SLASH_PERCENTAGE) / 100;
            stakingContract.slash(stakeId, slashAmount);
            emit EvaluatorSlashed(evaluator, slashAmount);
        }
    }

    function verifyZKP(uint256 roundNumber, address evaluator, bytes calldata proof) internal view returns (bool) {
        bytes32 storedZkpHash = zkpHashes[roundNumber][evaluator];
        bytes32 calculatedZkpHash = keccak256(proof);
        
        // In a real implementation, this would involve actual ZKP verification
        // For demonstration, we're just checking if the hashes match
        return storedZkpHash == calculatedZkpHash;
    }

    function getEvaluationHash(uint256 roundNumber, address evaluator) external view returns (bytes32) {
        return evaluationHashes[roundNumber][evaluator];
    }

    function getRoundEvaluators(uint256 roundNumber) external view returns (address[] memory) {
        return roundEvaluators[roundNumber];
    }

    function setMinimumStake(uint256 _minimumStake) external onlyOwner {
        minimumStake = _minimumStake;
    }

    function setStakingContract(address _newStakingContract) external onlyOwner {
        stakingContract = EvaluatorStaking(_newStakingContract);
    }
}
