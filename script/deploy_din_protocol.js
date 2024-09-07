const hre = require("hardhat");
const fs = require("fs");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  let deployedAddresses = {};
  
  try {
    deployedAddresses = JSON.parse(fs.readFileSync('deployed_addresses.json', 'utf8'));
  } catch (error) {
    console.log("No existing deployments found. Starting fresh deployment.");
  }

  async function deployOrReuse(contractName, ...args) {
    if (deployedAddresses[contractName]) {
      console.log(`Reusing ${contractName} at ${deployedAddresses[contractName]}`);
      return await ethers.getContractAt(contractName, deployedAddresses[contractName]);
    } else {
      const Contract = await hre.ethers.getContractFactory(contractName);
      const instance = args.length > 0 ? await Contract.deploy(...args) : await Contract.deploy();
      await instance.deployed();
      console.log(`${contractName} deployed to:`, instance.address);
      deployedAddresses[contractName] = instance.address;
      return instance;
    }
  }

  async function deployOrReuseProxy(contractName, initArgs) {
    if (deployedAddresses[contractName]) {
      console.log(`Reusing ${contractName} at ${deployedAddresses[contractName]}`);
      return await ethers.getContractAt(contractName, deployedAddresses[contractName]);
    } else {
      const Contract = await hre.ethers.getContractFactory(contractName);
      const instance = await upgrades.deployProxy(Contract, initArgs);
      await instance.deployed();
      console.log(`${contractName} deployed to:`, instance.address);
      deployedAddresses[contractName] = instance.address;
      return instance;
    }
  }

  // Deploy core contracts
  const dinToken = await deployOrReuse("DINToken");
  const stakeNFT = await deployOrReuseProxy("EvaluatorStaking", ["DIN Stake NFT", "DINSTAKE", ethers.utils.parseEther("100")]);
  const harbergerAuction = await deployOrReuse("HarbergerAuction", stakeNFT.address);
  const evaluatorRegistry = await deployOrReuse("EvaluatorRegistry", stakeNFT.address, ethers.utils.parseEther("100"));
  const aggregatorManagement = await deployOrReuse("AggregatorManagement", 5, 10, 3);
  const rewardDistribution = await deployOrReuseProxy("RewardDistribution", [dinToken.address, stakeNFT.address]);
  const intelligenceProtocol = await deployOrReuse("IntelligenceProtocol", 5, 10, stakeNFT.address, ethers.utils.parseEther("100"));

  // Set HarbergerAuction address in StakeNFT if not already set
  if ((await stakeNFT.harbergerAuction()) !== harbergerAuction.address) {
    await stakeNFT.setHarbergerAuction(harbergerAuction.address);
    console.log("HarbergerAuction address set in StakeNFT");
  }

  // Deploy DINProtocol
  const dinProtocol = await deployOrReuse("DINProtocol",
    intelligenceProtocol.address,
    aggregatorManagement.address,
    evaluatorRegistry.address,
    rewardDistribution.address,
    stakeNFT.address,
    harbergerAuction.address,
    dinToken.address
  );

  // Set up connections between contracts
  const contractsToTransfer = [
    { contract: stakeNFT, name: "StakeNFT" },
    { contract: harbergerAuction, name: "HarbergerAuction" },
    { contract: evaluatorRegistry, name: "EvaluatorRegistry" },
    { contract: aggregatorManagement, name: "AggregatorManagement" },
    { contract: rewardDistribution, name: "RewardDistribution" },
    { contract: intelligenceProtocol, name: "IntelligenceProtocol" }
  ];

  for (const { contract, name } of contractsToTransfer) {
    const currentOwner = await contract.owner();
    if (currentOwner !== dinProtocol.address) {
      await contract.transferOwnership(dinProtocol.address);
      console.log(`Ownership of ${name} transferred to DINProtocol`);
    } else {
      console.log(`${name} already owned by DINProtocol`);
    }
  }

  // Transfer initial tokens to RewardDistribution if needed
  const rewardDistributionBalance = await dinToken.balanceOf(rewardDistribution.address);
  if (rewardDistributionBalance.lt(ethers.utils.parseEther("1000000"))) {
    await dinToken.transfer(rewardDistribution.address, ethers.utils.parseEther("1000000").sub(rewardDistributionBalance));
    console.log("Initial tokens transferred to RewardDistribution");
  } else {
    console.log("RewardDistribution already has sufficient tokens");
  }

  console.log("DIN Protocol deployment and setup complete!");

  // Save deployed addresses
  fs.writeFileSync('deployed_addresses.json', JSON.stringify(deployedAddresses, null, 2));
  console.log("Deployed addresses saved to deployed_addresses.json");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
