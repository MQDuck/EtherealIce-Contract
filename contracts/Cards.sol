//SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;

import "./interfaces/ICards.sol";
import "./interfaces/IERC721Receiver.sol";
import "./lib/SafeMath.sol";
import "./lib/Address.sol";
import "./EnumerableUintSet.sol";

contract Cards is ICards {
    using SafeMath for uint;
    using Address for address;

    uint constant RARITY_COMMON = 0;
    uint constant RARITY_UNCOMMON = 1;
    uint constant RARITY_RARE = 2;
    uint constant RARITY_RAREST = 3;

    // Equals `IERC721Receiver(0).onERC721Received.selector`
    bytes4 private constant ERC721_RECEIVED = 0x150b7a02;

    // The type of each card by card ID
    uint[] cardsTypes;

    // Mapping from owner address to their list of owned cards
    mapping(address => uint[]) ownerCards;
    mapping(address => mapping(uint => uint)) ownerCardsIdx;

    // Mapping from card ID to owner address
    mapping(uint => address) private cardOwners;
    // Mapping from card ID to approved address
    mapping(uint => address) private cardApprovals;
    // Mapping from owner address to operator approvals
    mapping(address => mapping(address => bool)) private ownerOperators;

    // List of addresses that can be the monetary benefactor of pack purchases
    address[] private benefactors;
    mapping(address => uint) private benefactorIdx;

    // Total number of card types
    uint private numTypes;
    // List of Common card type IDs
    uint[] private typesCommon;
    // List of Uncommon card type IDs
    uint[] private typesUncommon;
    // List of Rare card type IDs
    uint[] private typesRare;
    // List of Rarest card type IDs
    uint[] private typesRarest;

    // Number of new cards printed per pack
    uint private cardsPerPack;
    // Price per pack in gwei
    uint private pricePerPack;

    // rarityMinRoll values used when deciding the rarity of new cards
    uint private rarityMinRollUncommon;
    uint private rarityMinRollRare;
    uint private rarityMinRollRarest;

    // A cheesy way to ensure random() returns different results in the same transaction
    uint private randomCount = 0;

    // The "publisher" (i.e. owner) of the contract
    address private publisher;

    // The name of the contract, perhaps identifying the game it's for
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

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) external view override returns (uint) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return ownerCards[owner].length;
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint cardId) external view override returns (address) {
        require(cardOwners[cardId] != address(0), "ERC721: owner query for nonexistent card");
        return cardOwners[cardId];
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint cardId, bytes calldata data) public override {
        transferFrom(from, to, cardId);

        if (to.isContract()) {
            bytes memory returndata = to.functionCall(abi.encodeWithSelector(
                    IERC721Receiver(to).onERC721Received.selector,
                    msg.sender,
                    from,
                    cardId,
                    data
                ), "ERC721: transfer to non ERC721Receiver implementer");
            bytes4 retval = abi.decode(returndata, (bytes4));
            require(retval == ERC721_RECEIVED);
        }
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint cardId) public override {
        //safeTransferFrom(from, to, cardId, "");
        transferFrom(from, to, cardId);

        if (to.isContract()) {
            bytes memory returndata = to.functionCall(abi.encodeWithSelector(
                    IERC721Receiver(to).onERC721Received.selector,
                    msg.sender,
                    from,
                    cardId,
                    ""
                ), "ERC721: transfer to non ERC721Receiver implementer");
            bytes4 retval = abi.decode(returndata, (bytes4));
            require(retval == ERC721_RECEIVED);
        }
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(address from, address to, uint cardId) public override {
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

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address approved, uint cardId) external override {
        require(msg.sender == cardOwners[cardId], "ERC721: approve caller is not owner");
        cardApprovals[cardId] = approved;

        emit Approval(msg.sender, approved, cardId);
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) external override {
        ownerOperators[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint cardId) external view override returns (address) {
        require(cardOwners[cardId] != address(0), "ERC721: approved query for nonexistent card");
        return cardApprovals[cardId];
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) external view override returns (bool) {
        return ownerOperators[owner][operator];
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == this.supportsInterface.selector
        || interfaceId == this.changePublisher.selector ^ this.addBenefactor.selector ^ this.removeBenefactor.selector ^ this.getBenefactors.selector ^ this.getName.selector ^ this.getPricePerPack.selector ^ this.buyPacks.selector ^ this.getOwnerCards.selector ^ this.getCardsTypes.selector;
    }

    /**
     * @dev Adds address to the list of approved benefactors
    */
    function addBenefactor(address benefactor) public override onlyPublisher {
        require(benefactorIdx[benefactor] == 0, "benefactor already approved");
        benefactors.push(benefactor);
        benefactorIdx[benefactor] = benefactors.length;

        emit BenefactorApproved(benefactor);
    }


    /**
     * @dev Removes address from the list of approved benefactors
    */
    function removeBenefactor(address benefactor) public override onlyPublisher {
        require(benefactorIdx[benefactor] != 0, "benefactor is already not approved");
        benefactors[benefactorIdx[benefactor] - 1] = benefactors[benefactors.length - 1];
        delete benefactors[benefactors.length - 1];
        benefactorIdx[benefactor] = 0;

        emit BenefactorRemoved(benefactor);
    }


    /**
     * @dev Adds new card types
     *
     * This function might be called when a new "expansion" is published.
    */
    function addTypes(
        uint numTypesCommon,
        uint numTypesUncommon,
        uint numTypesRare,
        uint numTypesRarest
    ) private onlyPublisher {
        uint stop = numTypes + numTypesCommon;
        for (uint i = 0; i < numTypesCommon; ++i) {
            typesCommon.push(numTypes);
            ++numTypes;
        }
        for (uint i = 0; i < numTypesUncommon; ++i) {
            typesUncommon.push(numTypes);
            ++numTypes;
        }
        for (uint i = 0; i < numTypesRare; ++i) {
            typesRare.push(numTypes);
            ++numTypes;
        }
        for (uint i = 0; i < numTypesRarest; ++i) {
            typesRarest.push(numTypes);
            ++numTypes;
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

    /**
     * @dev Adds a card ID to an owner address
    */
    function addCard(address owner, uint cardId) private {
        require(ownerCardsIdx[owner][cardId] == 0, "card already in set");
        ownerCards[owner].push(cardId);
        ownerCardsIdx[owner][cardId] = ownerCards[owner].length;
    }

    /**
     * @dev Removes a card ID from an owner address
    */
    function removeCard(address owner, uint cardId) private {
        require(ownerCardsIdx[owner][cardId] != 0, "card not in set");
        ownerCards[owner][ownerCardsIdx[owner][cardId] - 1] = ownerCards[owner][ownerCards[owner].length - 1];
        ownerCardsIdx[owner][ownerCards[owner][ownerCards[owner].length - 1]] = ownerCardsIdx[owner][cardId];
        ownerCardsIdx[owner][cardId] = 0;
        delete ownerCards[owner][ownerCards[owner].length - 1];
    }

    // TODO: Replace with something secure like Chainlink VRF.
    /**
     * @dev Generates a random number (insecurely)
    */
    function random() private returns (uint) {
        ++randomCount;
        return uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, randomCount)));
    }

    /**
     * @dev Prints a new card of cardType and gives it to the recipient owner address
    */
    function printCard(uint cardType, address recipient) private {
        emit CardPrinted(cardsTypes.length, cardType, recipient);

        addCard(recipient, cardsTypes.length);
        cardOwners[cardsTypes.length] = recipient;
        cardsTypes.push(cardType);
    }

    /**
     * @dev Randomly generates new cards for the recipient address, after paying a chosen benefactor address
    */
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

    function getCardsTypes() external view override returns (uint[] memory) {
        return cardsTypes;
    }
}




















