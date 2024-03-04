// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TimeMultisig} from "../generic/TimeMultisig.sol";
import {IStaking} from "../staking/IStaking.sol";

contract Launchpad is TimeMultisig {

    event Buy(address indexed owner, uint usdtAmount, uint visAmount);

    IERC20 private immutable visToken;
    uint private visDecimals;
    IERC20 private immutable usdtToken;
    IStaking public stakingContract;

    uint public totalSold = 0;
    uint public startPrice;  // Start price per 1 VIS token (10**18 wei)
    uint public endPrice;  // End price per 1 VIS token (10**18 wei)

    constructor(address visTokenAddress, address usdtTokenAddress, address[] memory _owners) TimeMultisig(_owners, 3, 600) {
        visToken = IERC20(visTokenAddress);
        visDecimals = 18;
        usdtToken = IERC20(usdtTokenAddress);
    }

    /**
     * @dev Calculates the current price for buying VIS tokens.
     * @param _amount The amount of VIS tokens to be bought.
     * @return price The current price for buying the specified amount of VIS tokens.
     */
    function currentPrice(uint _amount) public view returns (uint price) {
        require(startPrice > 0, "Launchpad: Invalid startPrice");
        require(endPrice > 0, "Launchpad: Invalid endPrice");
        uint remainingBalance = visToken.balanceOf(address(this));
        require(_amount <= remainingBalance, "Launchpad: Not enough tokens to sell");

        uint total = totalSold + remainingBalance;
        uint priceBeforeSlippage = startPrice + (totalSold * (endPrice - startPrice) / total);
        uint priceAfterSlippage = startPrice + ((totalSold + _amount) * (endPrice - startPrice) / total);
        price = (priceBeforeSlippage + priceAfterSlippage) * _amount / 2 / 10**visDecimals;
    }

    /**
     * @dev Allows users to buy VIS tokens by paying in USDT.
     * @param _amount The amount of VIS tokens to buy.
     * @param _stakingPeriod The staking period for the bought VIS tokens.
     */
    function buy(uint _amount, uint _stakingPeriod) public notPaused {
        uint usdtAmount = currentPrice(_amount);
        require(usdtToken.transferFrom(msg.sender, address(this), usdtAmount), "Launchpad: Token transfer failed");

        visToken.approve(address(stakingContract), _amount);
        stakingContract.stake(msg.sender, _amount, _stakingPeriod);

        totalSold += _amount;

        emit Buy(msg.sender, usdtAmount, _amount);
    }

    /**
     * @dev Sets the staking contract address.
     * @param _stakingContractAddress The address of the staking contract.
     */
    function setStakingContract(address _stakingContractAddress) public onlyOwner
            enoughApprovals(abi.encodePacked("SET_STAKING_CONTRACT", _stakingContractAddress)) {
        stakingContract = IStaking(_stakingContractAddress);
    }

    /**
     * @dev Sets the start and end prices for buying VIS tokens.
     * @param _startPrice The initial price of VIS tokens.
     * @param _endPrice The final price of VIS tokens.
     */
    function setPrices(uint _startPrice, uint _endPrice) public onlyOwner
            enoughApprovals(abi.encodePacked("SET_PRICES", _startPrice, _endPrice)) {
        require(_startPrice < _endPrice, "Launchpad: endPrice must be greater than startPrice");
        startPrice = _startPrice;
        endPrice = _endPrice;
    }

    /**
     * @dev Withdraws tokens from the contract balance to a specified address.
     * @param _contractAddress The address of the token contract.
     * @param _amount The amount of tokens to withdraw.
     * @param _toAddress The address to receive the tokens.
     */
    function withdrawBalance(address _contractAddress, uint _amount, address _toAddress) public onlyOwner
            enoughApprovals(abi.encodePacked("WITHDRAW_BALANCE", _contractAddress, _amount, _toAddress)) {
        require(_contractAddress != address(0));
        IERC20 token = IERC20(_contractAddress);
        require(token.transfer(_toAddress, _amount), "Launchpad: Token withdrawal failed");
    }

}
