//SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;

import "./interfaces/ICards.sol";
import "./lib/SafeMath.sol";
import "./EnumerableUintSet.sol";

contract Cards is ICards {
    using SafeMath for uint;
    using EnumerableUintSet for EnumerableUintSet.Set;

    // equal to bytes4(keccak256("onERC721Received(address,address,uint,bytes)"))
    bytes4 private constant ERC721_RECEIVED = 0x150b7a02;

    uint constant RARITY_COMMON = 0;
    uint constant RARITY_UNCOMMON = 1;
    uint constant RARITY_RARE = 2;
    uint constant RARITY_RAREST = 3;

    uint[] cardsTypes;

    mapping(address => uint[]) ownerCards;
    mapping(address => mapping(uint => uint)) ownerCardsIdx;

    function addCard(address owner, uint cardId) private {
        require(ownerCardsIdx[owner][cardId] == 0, "card already in set");
        ownerCards[owner].push(cardId);
        ownerCardsIdx[owner][cardId] = ownerCards[owner].length;
    }
    
    function removeCard(address owner, uint cardId) private {
        require(ownerCardsIdx[owner][cardId] != 0, "card not in set");
        ownerCards[owner][ownerCardsIdx[owner][cardId] - 1] = ownerCards[owner][ownerCards[owner].length - 1];
        ownerCardsIdx[owner][ownerCards[owner][ownerCards[owner].length - 1]] = ownerCardsIdx[owner][cardId];
        ownerCardsIdx[owner][cardId] = 0;
        delete ownerCards[owner][ownerCards[owner].length - 1];
    }

    mapping(uint => address) private cardOwners;
    mapping(uint => address) private cardApprovals;
    mapping(address => mapping(address => bool)) private ownerOperators;

    address[] private benefactors;
    mapping(address => uint) private benefactorIdx;

    uint numTypes;
    uint[] typesCommon;
    uint[] typesUncommon;
    uint[] typesRare;
    uint[] typesRarest;

    uint private cardsPerPack;
    uint pricePerPack;

    uint rarityMinRollUncommon;
    uint rarityMinRollRare;
    uint rarityMinRollRarest;

    uint private randomCount = 0;

    address private publisher;
    string private name;

    modifier onlyPublisher {
        require(msg.sender == publisher);
        _;
    }

    constructor(
        string memory _name,
        uint numTypesCommon,
        uint numTypesUncommon,
        uint numTypesRare,
        uint numTypesRarest,
        uint _pricePerPack,
        uint _cardsPerPack,
        uint _rarityMinRollUncommon,
        uint _rarityMinRollRare,
        uint _rarityMinRollRarest,
        address[] memory _benefactors
    ) {
        require(
            _rarityMinRollUncommon < _rarityMinRollRare
            && _rarityMinRollRare < _rarityMinRollRarest,
            "Invalid rarity roll parameters"
        );
        require(_cardsPerPack >= 1 && _cardsPerPack <= 42, "must be (1 <= cardsPerPack <= 42");

        publisher = msg.sender;
        name = _name;
        pricePerPack = _pricePerPack;
        cardsPerPack = _cardsPerPack;
        rarityMinRollUncommon = _rarityMinRollUncommon;
        rarityMinRollRare = _rarityMinRollRare;
        rarityMinRollRarest = _rarityMinRollRarest;

        for (uint i = 0; i < _benefactors.length; ++i) {
            addBenefactor(_benefactors[i]);
        }

        addTypes(numTypesCommon, numTypesUncommon, numTypesRare, numTypesRarest);
    }

    function balanceOf(address owner) external view override returns (uint) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return ownerCards[owner].length;
    }

    // TODO: test if storing value is cheaper
    function ownerOf(uint cardId) external view override returns (address) {
        require(cardOwners[cardId] != address(0), "ERC721: owner query for nonexistent card");
        return cardOwners[cardId];
    }

    // TODO: make safe
    function safeTransferFrom(address from, address to, uint cardId, bytes calldata data) external override {
        _safeTransferFrom(from, to, cardId, data);
    }

    function safeTransferFrom(address from, address to, uint cardId) external override {
        _safeTransferFrom(from, to, cardId, "");
    }

    function _safeTransferFrom(address from, address to, uint cardId, bytes memory data) private {
        _transfer(from, to, cardId);
    }

    function transferFrom(address from, address to, uint cardId) external override {
        _transfer(from, to, cardId);
    }

    function _transfer(address from, address to, uint cardId) private {
        require(
            msg.sender == cardOwners[cardId] || ownerOperators[from][msg.sender] || msg.sender == cardApprovals[cardId],
            "ERC721: transfer caller is not owner or approved"
        );
        require(cardOwners[cardId] == from, "ERC721: transfer from is not owner");
        require(to != address(0), "ERC721: transfer to is zero address");
        require(cardOwners[cardId] != address(0), "ERC721: transfer call for nonexistent card");

        removeCard(from, cardId);
        addCard(to, cardId);
        cardOwners[cardId] = to;
        cardApprovals[cardId] = address(0);

        emit Transfer(from, to, cardId);
    }

    function approve(address approved, uint cardId) external override {
        require(msg.sender == cardOwners[cardId], "ERC721: approve caller is not owner");
        cardApprovals[cardId] = approved;

        emit Approval(msg.sender, approved, cardId);
    }

    function setApprovalForAll(address operator, bool approved) external override {
        ownerOperators[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function getApproved(uint cardId) external view override returns (address) {
        require(cardOwners[cardId] != address(0), "ERC721: approved query for nonexistent card");
        return cardApprovals[cardId];
    }

    function isApprovedForAll(address owner, address operator) external view override returns (bool) {
        return ownerOperators[owner][operator];
    }

    // TODO
    function supportsInterface(bytes4 interfaceId) external view override returns (bool) {
        return false;
    }

    function addBenefactor(address benefactor) public override onlyPublisher {
        require(benefactorIdx[benefactor] == 0, "benefactor already approved");
        benefactors.push(benefactor);
        benefactorIdx[benefactor] = benefactors.length;

        emit BenefactorApproved(benefactor);
    }

    function removeBenefactor(address benefactor) public override onlyPublisher {
        require(benefactorIdx[benefactor] != 0, "benefactor is already not approved");
        benefactors[benefactorIdx[benefactor] - 1] = benefactors[benefactors.length - 1];
        delete benefactors[benefactors.length - 1];
        benefactorIdx[benefactor] = 0;

        emit BenefactorRemoved(benefactor);
    }

    // END ERC721 STUFF

    function addTypes(
        uint numTypesCommon,
        uint numTypesUncommon,
        uint numTypesRare,
        uint numTypesRarest
    ) private onlyPublisher {
        for (; numTypes < numTypesCommon; ++numTypes) {
            typesCommon.push(numTypes);
        }
        for (; numTypes < numTypesCommon + numTypesUncommon; ++numTypes) {
            typesUncommon.push(numTypes);
        }
        for (; numTypes < numTypesUncommon + numTypesUncommon + numTypesRare; ++numTypes) {
            typesRare.push(numTypes);
        }
        for (; numTypes < numTypesCommon + numTypesUncommon + numTypesRare + numTypesRarest; ++numTypes) {
            typesRarest.push(numTypes);
        }
    }

    function getBenefactors() external view override returns (address[] memory) {
        return benefactors;
    }

    function changePublisher(address newPublisher) external override onlyPublisher {
        require(newPublisher != address(0), "publisher cannot be address(0)");
        publisher = newPublisher;

        emit PublisherChanged(newPublisher);
    }

    function getName() external view override returns (string memory) {
        return name;
    }

    function getPricePerPack() external view override returns (uint) {
        return pricePerPack;
    }

    // TODO: Replace with something secure like Chainlink VRF.
    function random() private returns (uint) {
        ++randomCount;
        return uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, randomCount)));
    }

    function printCard(uint cardType, address recipient) private {
        emit CardPrinted(cardsTypes.length, cardType, recipient);

//        ownerCards[recipient].add(cards.length);
        addCard(recipient, cardsTypes.length);
        cardOwners[cardsTypes.length] = recipient;
        cardsTypes.push(cardType);
    }

    function buyPacks(uint numPacks, address recipient, address payable benefactor) external payable override {
        require(msg.value == numPacks * pricePerPack, "numPacks and message value do not match");
        require(benefactorIdx[benefactor] != 0, "benefactor is not in the approved list");

        benefactor.transfer(msg.value);

        emit PacksBought(numPacks, msg.sender);

        for (uint pack = 0; pack < numPacks; ++pack) {
            uint rarityRoll = random();
            for (uint card = 0; card < cardsPerPack; ++card) {
                uint cardRarityRoll = rarityRoll % 64;

                if (cardRarityRoll >= rarityMinRollRarest) {
                    printCard(typesRarest[random() % typesRarest.length], recipient);
                } else if (cardRarityRoll >= rarityMinRollRare) {
                    printCard(typesRare[random() % typesRare.length], recipient);
                } else if (cardRarityRoll >= rarityMinRollUncommon) {
                    printCard(typesUncommon[random() % typesUncommon.length], recipient);
                } else {
                    printCard(typesCommon[random() % typesCommon.length], recipient);
                }

                rarityRoll >>= 6;
            }
        }
    }

    function getOwnerCards(address owner) external view override returns (uint[] memory) {
        return ownerCards[owner];
    }

    function getCardsTypes() external view override returns(uint[] memory) {
        return cardsTypes;
    }
}




















