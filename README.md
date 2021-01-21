# EtherealIce

A smart contract designed for the soon-to-be hit trading card game EtherealIce: The Decentralization.

## About EtherealIce
Unlike other pay-to-win card games that are designed to extract maximum profit from players, EtherealIce is a pay-to-win card game designed to raise money for charity. When purchasing packs, players choose from a list of approved beneficiary addresses to receive the entirety of the transaction value.

## About the contract
The EtherealIce contract conforms to the [ERC-721 Non-Fungible Token Standard](https://eips.ethereum.org/EIPS/eip-721). Limited game information is stored in the contract. Specifically, the list of card types and their corresponding rarity. All other game information (such as game rules and other properties of each card type) are part of the game server and client.

New cards are created at the time of purchase, randomly selected from among the existing card types based probabalistically on their corresponding rarity.

The "publisher" (i.e. owner) of the contract controls rarity parameters and the list of approved beneficiaries. The publisher can release "expansions" by adding new card types.

## Potential improvements

The random() function used is insecure. It should be replaced by something like [Chainlink VRF](https://docs.chain.link/docs/chainlink-vrf). As this would increase the cost of random() calls, making an effort to minimize them becomes worthwhile.

As the buyPacks() function is currently written, random() is called once to determine the rarities of all cards, and then an additional time for each card to determine its type. With a pack size of **P**, this results in **P + 1** calls. If the maximum number of card types per rarity is decreased, the number of random() calls can be greatly reduced. With a maximum of **M** types per rarity, then the number of random() calls per pack can be reduced to one so long as **(log_2(M) + 6)P <= 256**. For instance, with ten cards per pack, you could have a maximum of 524,288 types per rarity, which is reasonable, and only one random() call per pack.

## Running
### Preparing
`npm install`
### Building
`npx hardhat compile`
### Testing
`npx hardhat test`
