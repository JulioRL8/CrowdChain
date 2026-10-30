// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.34;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/CrowdChainToken.sol";

contract CrowdChain {
    address owner;
    address token;
    uint256 moneyTarget;
    uint256 initialTimestamp;
    uint256 duration;
    uint256 totalBalance = 0;
    uint256 public balanceRetiredByOwner = 0;
    mapping(address => uint256) public userBalance;
    mapping(address => bool) public rewardsReclaimed;

    // Constants
    uint256 constant minDuration = 1 days;
    uint256 public constant tokenConversion = 100;

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, NotOwner());
        _;
    }

    // Errors
    // Initialization
    error OwnerNotValid();
    error TokenAddressNotValid();
    error DurationLessThanMinimumAllowed();
    error MoneyTargetZero();

    // Functional errors
    error CrowdFundingNotActive();
    error NoMoneyReceived();
    error ContributeOverTarget();
    error CrowdFundingStillActive();
    error CroudFundingNotCompleted();
    error NotAvailableAmount();
    error PaymentFailed();
    error CrowdFundingCompleted();
    error NotOwner();
    error NoRewardAvailable();
    error AlreadyReclaimedRewards();

    // Events
    event Contribute(address user, uint256 amount);
    event ExtractFunds(uint256 amount);
    event RecoverFunds(address user, uint256 amount);
    event ReclaimRewards(address user, uint256 reward);

    constructor(address owner_, address token_, uint256 moneyTarget_, uint256 duration_) {
        require(owner_ != address(0), OwnerNotValid());
        require(token_ != address(0), TokenAddressNotValid());
        require(duration_ >= minDuration, DurationLessThanMinimumAllowed());
        require(moneyTarget_ > 0, MoneyTargetZero());
        token = token_;
        owner = owner_;
        moneyTarget = moneyTarget_;
        duration = duration_;
        initialTimestamp = block.timestamp;
    }

    // External functions
    function contribute() external payable {
        require(isActive(), CrowdFundingNotActive());
        require(msg.value > 0, NoMoneyReceived());

        uint256 newValue = totalBalance + msg.value;
        require(newValue <= moneyTarget, ContributeOverTarget());

        totalBalance = newValue;
        userBalance[msg.sender] += msg.value;

        emit Contribute(msg.sender, msg.value);
    }

    function moneyToCompleteTarget() external view returns (uint256) {
        return moneyTarget - totalBalance;
    }

    function completedWithSuccess() public view returns (bool) {
        return totalBalance >= moneyTarget;
    }

    function remainingTime() external view returns (uint256) {
        if (totalBalance >= moneyTarget) return 0;
        if (currentTime() > duration) return 0;
        return duration - currentTime();
    }

    function extractFunds(uint256 amount) external onlyOwner {
        require(!isActive(), CrowdFundingStillActive());
        require(completedWithSuccess(), CroudFundingNotCompleted());

        uint256 availableAmount = totalBalance - balanceRetiredByOwner;
        require(amount <= availableAmount, NotAvailableAmount());

        balanceRetiredByOwner += amount;
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, PaymentFailed());

        emit ExtractFunds(amount);
    }

    function recoverFunds() external {
        require(!isActive(), CrowdFundingStillActive());
        require(!completedWithSuccess(), CrowdFundingCompleted());

        uint256 amount = userBalance[msg.sender];
        require(amount > 0, NotAvailableAmount());

        userBalance[msg.sender] = 0;

        (bool success,) = msg.sender.call{value: amount}("");
        require(success, PaymentFailed());

        emit RecoverFunds(msg.sender, amount);
    }

    function reclaimRewards() external {
        require(!isActive(), CrowdFundingStillActive());
        require(completedWithSuccess(), CroudFundingNotCompleted());

        uint256 balance = userBalance[msg.sender];
        require(balance > 0, NoRewardAvailable());

        require(!rewardsReclaimed[msg.sender], AlreadyReclaimedRewards());

        uint256 reward = balance * tokenConversion;
        rewardsReclaimed[msg.sender] = true;
        CrowdChainToken(token).mint(msg.sender, reward);

        emit ReclaimRewards(msg.sender, reward);
    }

    // Internal functions
    function isActive() internal view returns (bool) {
        return !timeGone() && totalBalance < moneyTarget;
    }

    function timeGone() internal view returns (bool) {
        return initialTimestamp + duration <= block.timestamp;
    }

    function currentTime() internal view returns (uint256) {
        return block.timestamp - initialTimestamp;
    }
}
