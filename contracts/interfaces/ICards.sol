//SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;

import "./IERC721.sol";

interface ICards is IERC721 {
    event BenefactorApproved(address benefactor);
    event BenefactorRemoved(address benefactor);
    event PublisherChanged(address newPublisher);
    event PacksBought(uint numPacks, address buyer);
    event CardPrinted(uint cardId, uint cardType, address recipient);

    function changePublisher(address newPublisher) external;
    function addBenefactor(address benefactor) external;
    function removeBenefactor(address benefactor) external;
    function getBenefactors() external view returns(address[] memory);
    function getName() external view returns(string memory);
    function getPricePerPack() external view returns (uint price);
    function buyPacks(uint numPacks, address recipient, address payable benefactor) external payable;
}