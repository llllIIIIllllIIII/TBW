// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract ChristmasTreeGame is Ownable {
    struct Player {
        mapping(address => uint256) deposits; // Player's token deposits
        uint256 totalValue; // Total stablecoin value of deposits
    }

    struct Tree {
        uint256 totalValue; // Total value of the tree in stablecoins
        bool depositsOpen; // Whether deposits are open
    }

    mapping(address => Player) public players; // Player data
    Tree public tree; // Current tree data
    mapping(address => AggregatorV3Interface) public priceFeeds; // Token price feeds

    address[] public acceptedTokens; // List of accepted ERC-20 tokens
    uint256 public depositDeadline; // Deadline for deposits

    event TokenDeposited(address indexed player, address indexed token, uint256 amount, uint256 value);
    event DepositsClosed();
    event TreeEvaluated(uint256 totalValue);

    constructor(address[] memory _acceptedTokens, address[] memory _priceFeeds) Ownable(msg.sender){
        require(_acceptedTokens.length == _priceFeeds.length, "Tokens and price feeds must match");

        for (uint256 i = 0; i < _acceptedTokens.length; i++) {
            acceptedTokens.push(_acceptedTokens[i]);
            priceFeeds[_acceptedTokens[i]] = AggregatorV3Interface(_priceFeeds[i]);
        }
        tree.depositsOpen = true; // Enable deposits initially
    }

    function deposit(address token, uint256 amount) external {
        require(tree.depositsOpen, "Deposits are closed");
        require(isAcceptedToken(token), "Token not accepted");

        IERC20(token).transferFrom(msg.sender, address(this), amount);

        uint256 tokenValue = getTokenValue(token, amount);
        players[msg.sender].deposits[token] += amount;
        players[msg.sender].totalValue += tokenValue;

        tree.totalValue += tokenValue;

        emit TokenDeposited(msg.sender, token, amount, tokenValue);
    }

    function closeDeposits() external onlyOwner {
        require(tree.depositsOpen, "Deposits already closed");
        require(block.timestamp >= depositDeadline, "Cannot close deposits yet");

        tree.depositsOpen = false;
        emit DepositsClosed();
    }

    function evaluateTree() external onlyOwner {
        require(!tree.depositsOpen, "Deposits are still open");

        emit TreeEvaluated(tree.totalValue);
    }

    function isAcceptedToken(address token) public view returns (bool) {
        for (uint256 i = 0; i < acceptedTokens.length; i++) {
            if (acceptedTokens[i] == token) {
                return true;
            }
        }
        return false;
    }

    function getTokenValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = priceFeeds[token];
        (, int256 price, , , ) = priceFeed.latestRoundData();
        require(price > 0, "Invalid price from oracle");

        return (uint256(price) * amount) / (10**IERC20WithDecimals(token).decimals());
    }

    function setDepositDeadline(uint256 _deadline) external onlyOwner {
        depositDeadline = _deadline;
    }

    function getTokenPrice(address token) public view returns (int256){
        AggregatorV3Interface priceFeed = priceFeeds[token];
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return price;        
    }

}

interface IERC20WithDecimals is IERC20 {
    function decimals() external view returns (uint8);
}

