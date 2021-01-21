//SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;

import "./IERC721.sol";

interface ICards is IERC721 {
    event BeneficiaryApproved(address beneficiary);
    event BeneficiaryRemoved(address beneficiary);
    event PublisherChanged(address newPublisher);
    event PacksBought(uint numPacks, address buyer);
    event CardPrinted(uint cardId, uint cardType, address recipient);

    function changePublisher(address newPublisher) external;
    function addBeneficiary(address beneficiary) external;
    function removeBeneficiary(address beneficiary) external;
    function getBeneficiaries() external view returns(address[] memory);
    function getName() external view returns(string memory);
    function getPricePerPack() external view returns (uint price);
    function buyPacks(uint numPacks, address recipient, address payable beneficiary) external payable;
    function getOwnerCards(address owner) external view returns(uint[] memory);
    function getCardsTypes() external view returns(uint[] memory);
}