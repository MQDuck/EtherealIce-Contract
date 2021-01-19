async function main() {

  const [deployer] = await ethers.getSigners();

  console.log(
    "Deploying contracts with the account:",
    deployer.address
  );

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const Cards = await ethers.getContractFactory("Cards");
  const cards = await Cards.deploy(
    "EtherealIce: The Decentralization",
    128,
    64,
    32,
    16,
    1500000,
    5,
    45,
    60,
    63,
    [ethers.utils.getAddress("0x0a7521653FdC62FbD124c88708d5B633ADBc3725")],
    {gasLimit: 1500000}
  );

  console.log("Cards address:", cards.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
