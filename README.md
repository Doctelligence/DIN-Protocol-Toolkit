# DIN-Protocol-Toolkit

The **DIN-Protocol-Toolkit** provides a comprehensive set of tools and resources for deploying and managing smart contracts related to the Decentralized Intelligence Network (DIN) protocol. This toolkit includes smart contracts, a deployment script, and utility code to support federated learning and decentralized systems.

## Project Structure

- **src/**: Contains utility scripts and code related to federated learning and other functionalities.
  - `secure_aggregation.py`: Code for secure aggregation processes.
  - `model_utils.py`: Utilities for model operations.
  - `ipfs_utils.py`: Utilities for IPFS interactions.
  - `fl_client.py`: Client for interacting with federated learning components.
  - `crypto_utils.py`: Cryptographic utilities.

- **script/**: Includes the deployment script for the smart contracts.
  - `deploy_din_protocol.js`: Deploys all DIN protocol related contracts.

- **contracts/**: Contains the Solidity smart contracts used in the DIN protocol.
  - `StakeNFT.sol`: Contract for staking NFTs.
  - `RewardDistribution.sol`: Handles reward distribution logic.
  - `IntelligenceProtocol.sol`: Core protocol contract.
  - `HarbergerAuction.sol`: Implements Harberger auction mechanism.
  - `EvaluatorRegistry.sol`: Manages evaluator registrations.
  - `ERC721-Stake.sol`: ERC721 token with staking functionality.
  - `DINProtocol.sol`: Main DIN protocol contract.
  - `AggregatorManagement.sol`: Manages aggregators within the network.

## Getting Started

To get started with the DIN-Protocol-Toolkit, follow these steps:

### Prerequisites

1. **Node.js**: Ensure that you have Node.js installed. You can download it from [nodejs.org](https://nodejs.org/).
2. **Hardhat**: Install Hardhat, a development environment for Ethereum, using the following command:
   ```bash
   npm install --save-dev hardhat

## Installation
Clone the repository:
     ```bash
  git clone https://github.com/your-organization/DIN-Protocol-Toolkit.git
  cd DIN-Protocol-Toolkit

Install the dependencies:
    ```bash
  npm install

## Deployment

To deploy the smart contracts, run the deployment script with Hardhat:
    ```bash
  npx hardhat run script/deploy_din_protocol.js --network <network_name>
  Replace <network_name> with the name of the network you are deploying to (e.g., localhost, ropsten, mainnet, etc.).

## Usage
Interacting with Contracts: Use the provided Python scripts in the src/ directory to interact with deployed contracts and perform federated learning operations.
Updating Contracts: Modify the Solidity files in the contracts/ directory to update or add new functionality. Be sure to redeploy the contracts after making changes.

## Contributing
We welcome contributions to the DIN-Protocol-Toolkit. To contribute:

1. Fork the repository.
2. Create a new branch for your changes.
3. Make your changes and commit them.
4. Push your branch and create a pull request.

Please follow the project's coding standards and guidelines.

## License
This project is licensed under the MIT License. See the LICENSE file for details.

## Contact
For questions or support, please contact us at abrahamnash@protonmail.com.

Thank you for using DIN-Protocol-Toolkit! We look forward to your contributions and feedback.
