// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {TimeMultisig} from "../generic/TimeMultisig.sol";
import {IStaking} from "../staking/IStaking.sol";

contract Launchpad is TimeMultisig, ReentrancyGuard {

    event Buy(address indexed owner, uint usdtAmount, uint visAmount);

    IERC20 private immutable visToken;
    IERC20 private immutable usdtToken;
    IStaking public stakingContract;

    uint public totalSold = 0;
    uint public startPrice;
    uint public endPrice;

    constructor(address visTokenAddress, address usdtTokenAddress, address[] memory _owners) TimeMultisig(_owners, 3, 600) {
        visToken = IERC20(visTokenAddress);
        usdtToken = IERC20(usdtTokenAddress);
    }

    function currentPrice(uint _amount) public view returns (uint price) {
        require(startPrice > 0, "Launchpad: Invalid startPrice");
        require(endPrice > 0, "Launchpad: Invalid endPrice");
        uint remainingBalance = visToken.balanceOf(address(this));
        require(_amount <= remainingBalance, "Launchpad: Not enough tokens to sell");

        uint total = totalSold + remainingBalance;
        uint priceBeforeSlippage = startPrice + (totalSold * (endPrice - startPrice) / total);
        uint priceAfterSlippage = startPrice + ((totalSold + _amount) * (endPrice - startPrice) / total);
        price = (priceBeforeSlippage + priceAfterSlippage) * _amount / 2;
    }

    function buy(uint _amount, uint _stakingPeriod) public notPaused nonReentrant {
        uint usdtAmount = currentPrice(_amount);
        require(usdtToken.transferFrom(msg.sender, address(this), usdtAmount), "Launchpad: Token transfer failed");

        visToken.approve(address(stakingContract), _amount);
        stakingContract.stake(msg.sender, _amount, _stakingPeriod);

        totalSold += _amount;

        emit Buy(msg.sender, usdtAmount, _amount);
    }

    function setStakingContract(address _stakingContractAddress) public onlyOwner enoughApprovals {
        stakingContract = IStaking(_stakingContractAddress);
    }

    function setPrices(uint _startPrice, uint _endPrice) public onlyOwner enoughApprovals {
        require(_startPrice < _endPrice, "Launchpad: endPrice must be greater than startPrice");
        startPrice = _startPrice;
        endPrice = _endPrice;
    }

    function withdrawBalance(address _contractAddress, uint _amount, address _toAddress) public nonReentrant onlyOwner enoughApprovals {
        require(_contractAddress != address(0));
        IERC20 token = IERC20(_contractAddress);
        require(token.transfer(_toAddress, _amount), "Launchpad: Token withdrawal failed");
    }

}
