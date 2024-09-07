// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract RewardDistribution is Initializable, ReentrancyGuardUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    using SafeMathUpgradeable for uint256;

    IERC20Upgradeable public rewardToken;
    address public stakingContract;
    uint256 public participantRewardPercentage;
    uint256 public currentRound;
    bool public isFinalRound;

    mapping(uint256 => mapping(address => uint256)) public participantScores;
    mapping(uint256 => address[]) public roundParticipants;
    mapping(uint256 => uint256[]) public roundScores;

    event RewardDeposited(address indexed depositor, uint256 amount);
    event ScoreSubmitted(address indexed evaluator, uint256 roundNumber, address indexed participant, uint256 score);
    event RewardDistributed(address indexed participant, uint256 roundNumber, uint256 reward);
    event EvaluatorRewardDistributed(address indexed evaluator, uint256 roundNumber, uint256 reward);
    event FinalRoundStarted(uint256 roundNumber);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _rewardToken, address _stakingContract) public initializer {
        __ReentrancyGuard_init();
        __Ownable_init();
        __UUPSUpgradeable_init();

        rewardToken = IERC20Upgradeable(_rewardToken);
        stakingContract = _stakingContract;
        participantRewardPercentage = 95; // 95% for participants, 5% for evaluators
        currentRound = 0;
        isFinalRound = false;
    }

    modifier onlyEvaluator() {
        require(EvaluatorStaking(stakingContract).isStaked(msg.sender), "Only staked evaluators can perform this action");
        _;
    }

    function setStakingContract(address _stakingContract) external onlyOwner {
        stakingContract = _stakingContract;
    }

    function depositReward(uint256 amount) external {
        require(rewardToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        emit RewardDeposited(msg.sender, amount);
    }

    function submitScore(uint256 _roundNumber, address _participant, uint256 _score) external onlyEvaluator {
        require(_roundNumber == currentRound && isFinalRound, "Scores can only be submitted in the final round");
        participantScores[_roundNumber][_participant] = _score;
        if (!isParticipantInRound(_roundNumber, _participant)) {
            roundParticipants[_roundNumber].push(_participant);
        }
        roundScores[_roundNumber].push(_score);
        emit ScoreSubmitted(msg.sender, _roundNumber, _participant, _score);
    }

    function isParticipantInRound(uint256 _roundNumber, address _participant) internal view returns (bool) {
        for (uint i = 0; i < roundParticipants[_roundNumber].length; i++) {
            if (roundParticipants[_roundNumber][i] == _participant) {
                return true;
            }
        }
        return false;
    }

    function startFinalRound() external onlyOwner {
        require(!isFinalRound, "Final round already started");
        currentRound++;
        isFinalRound = true;
        emit FinalRoundStarted(currentRound);
    }

    function distributeRewards() external nonReentrant onlyOwner {
        require(isFinalRound, "Can only distribute rewards after the final round");
        uint256 totalReward = rewardToken.balanceOf(address(this));
        uint256 participantReward = (totalReward * participantRewardPercentage) / 100;
        uint256 evaluatorReward = totalReward - participantReward;

        distributeParticipantRewards(currentRound, participantReward);
        distributeEvaluatorRewards(currentRound, evaluatorReward);

        // Reset for next training cycle
        isFinalRound = false;
        currentRound++;
    }

    function distributeParticipantRewards(uint256 _roundNumber, uint256 _totalReward) internal {
        uint256 totalValidScore = 0;
        uint256 participantCount = roundParticipants[_roundNumber].length;
        
        for (uint i = 0; i < participantCount; i++) {
            totalValidScore = totalValidScore.add(participantScores[_roundNumber][roundParticipants[_roundNumber][i]]);
        }

        for (uint i = 0; i < participantCount; i++) {
            address participant = roundParticipants[_roundNumber][i];
            uint256 score = participantScores[_roundNumber][participant];
            uint256 reward = (_totalReward * score) / totalValidScore;
            
            require(rewardToken.transfer(participant, reward), "Reward transfer failed");
            emit RewardDistributed(participant, _roundNumber, reward);
        }
    }

    function distributeEvaluatorRewards(uint256 _roundNumber, uint256 _totalReward) internal {
        uint256 evaluatorCount = 0;
        for (uint i = 0; i < roundParticipants[_roundNumber].length; i++) {
            if (EvaluatorStaking(stakingContract).isStaked(roundParticipants[_roundNumber][i])) {
                evaluatorCount++;
            }
        }

        require(evaluatorCount > 0, "No evaluators for this round");
        uint256 evaluatorReward = _totalReward / evaluatorCount;

        for (uint i = 0; i < roundParticipants[_roundNumber].length; i++) {
            address evaluator = roundParticipants[_roundNumber][i];
            if (EvaluatorStaking(stakingContract).isStaked(evaluator)) {
                require(rewardToken.transfer(evaluator, evaluatorReward), "Evaluator reward transfer failed");
                emit EvaluatorRewardDistributed(evaluator, _roundNumber, evaluatorReward);
            }
        }
    }

    function getParticipantScore(uint256 _roundNumber, address _participant) external view returns (uint256) {
        return participantScores[_roundNumber][_participant];
    }

    function getRoundParticipants(uint256 _roundNumber) external view returns (address[] memory) {
        return roundParticipants[_roundNumber];
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
