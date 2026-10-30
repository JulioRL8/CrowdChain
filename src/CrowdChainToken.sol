// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.34;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CrowdChainToken is ERC20 {

    address owner;
    address public crowdChain;

    // Errors
    error Forbidden();
    error OwnerNotValid();
    error AddressNotValid();
    error CrowdChainNotProvided();
    error CrowdChainAlreadyProvided();

    // Events
    event CrowdChainProvided();

    modifier onlyOwner {
        require(owner == msg.sender, Forbidden());
        _;
    }

    modifier onlyCrowdChain {
        require(crowdChain != address(0), CrowdChainNotProvided());
        require(crowdChain == msg.sender, Forbidden());
        _;
    }

    constructor(address owner_) ERC20("CrowdChain Token", "CCT") {
        require(owner_ != address(0), OwnerNotValid());
        owner = owner_;
    }

    function provideCrowdChain(address crowdChain_) external onlyOwner() {
        require(crowdChain_ != address(0), AddressNotValid());
        require(crowdChain == address(0), CrowdChainAlreadyProvided());
        crowdChain = crowdChain_;
        
        emit CrowdChainProvided();
    }

    function mint(address to_, uint256 amount_) external onlyCrowdChain() {
        _mint(to_, amount_);
    }
}