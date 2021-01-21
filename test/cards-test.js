const {expect} = require("chai");

const NUM_TYPES_COMMON = 128;
const NUM_TYPES_UNCOMMON = 64;
const NUM_TYPES_RARE = 32;
const NUM_TYPES_RAREST = 16;
const PRICE_PER_PACK = 1500000;
const CARDS_PER_PACK = 5;
const RARITY_MIN_ROLL_UNCOMMON = 45;
const RARITY_MIN_ROLL_RARE = 60;
const RARITY_MIN_ROLL_RAREST = 63;

describe("Cards", function () {
  let cards;
  let addr1, addr2, addr3, addr4, addr5, addr6;

  it("deploy contract", async function () {
    [owner, addr1, addr2, addr3, addr4, addr5, addr6] = await ethers.getSigners();
    const Cards = await ethers.getContractFactory("Cards");
    cards = await Cards.deploy(
      "EtherealIce: The Decentralization",
      NUM_TYPES_COMMON,
      NUM_TYPES_UNCOMMON,
      NUM_TYPES_RARE,
      NUM_TYPES_RAREST,
      PRICE_PER_PACK,
      CARDS_PER_PACK,
      RARITY_MIN_ROLL_UNCOMMON,
      RARITY_MIN_ROLL_RARE,
      RARITY_MIN_ROLL_RAREST,
      [addr4.address]
    );
    await cards.deployed();

    console.log("Card contract deployed")
  });

  it("buy pack", async function () {
    expect((await cards.getOwnerCards(addr1.address)).length).to.equal(0);
    await cards.connect(addr2).buyPacks(
      3,
      addr1.address,
      addr4.address,
      {value: PRICE_PER_PACK * 3}
    );
    const addr1Cards = await cards.getOwnerCards(addr1.address)
    expect(addr1Cards.length).to.equal(3 * CARDS_PER_PACK);

    const cardsTypes = (await cards.getCardsTypes()).map(num => num.toNumber());
    console.log(
      "3 packs printed with the following card types: ",
      addr1Cards.map(cardId => cardsTypes[cardId.toNumber()])
    );
  });

  it("transfer card", async function() {
    const card2 = (await cards.getOwnerCards(addr1.address))[2];
    let fail = false;
    try {
      await cards.connect(addr3).transferFrom(addr1.address, addr2.address, card2);
      fail = true;
    } catch (e) {}
    if (fail) expect.fail();
    await cards.connect(addr1).approve(addr3.address, card2);
    await cards.connect(addr3).transferFrom(addr1.address, addr2.address, card2);

    const addr1Cards = await cards.getOwnerCards(addr1.address);
    const addr2Cards = await cards.getOwnerCards(addr2.address);
    expect(addr1Cards[2]).not.equal(card2);
    expect(addr2Cards[0]).to.equal(card2);
    expect(addr1Cards.length).to.equal(3 * CARDS_PER_PACK - 1);
    expect(addr2Cards.length).to.equal(1);

    console.log(`card ${card2} transferred from ${addr1.address} to ${addr2.address} by approved address ${addr3.address}`);
  });

  it("change beneficiaries", async function() {
    let fail = false;
    try {
      await cards.connect(addr2).addBeneficiary(addr2.address);
      fail = true;
    } catch (e) {}
    if (fail) expect.fail();
    const numBeneficiaries = (await cards.getBeneficiaries()).length;
    cards.addBeneficiary(addr5.address);
    expect((await cards.getBeneficiaries()).length).to.equal(numBeneficiaries + 1);
    cards.connect(addr3).buyPacks(
      2,
      addr3.address,
      addr5.address,
      {value: PRICE_PER_PACK * 2}
    );

    console.log(`beneficiary ${addr5.address} added to approved beneficiaries list`);

    fail = false;
    try {
      await cards.connect(addr4).removeBeneficiary(addr4.address);
      fail = true;
    } catch (e) {}
    if (fail) expect.fail();
    await cards.removeBeneficiary(addr4.address);
    expect((await cards.getBeneficiaries()).length).to.equal(numBeneficiaries);
    fail = false;
    try {
      await cards.connect(addr6).buyPacks(
        2,
        addr6.address,
        addr4.address,
        {value: PRICE_PER_PACK * 2}
      );
      fail = true;
    } catch (e) {}
    if (fail) expect.fail();

    console.log(`beneficiary ${addr4.address} removed from approved beneficiaries list`);
  })
});
