// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract Insurance is ReentrancyGuard {
  AggregatorV3Interface internal priceFeed;

  error WrongMonthAmountInsurance();
  error NoFundsToWithdraw();

  event InsuranceCreation(
    address indexed creator,
    uint indexed insuredAmount,
    uint indexed percentageCoverage,
    uint premiumPaid,
    uint insuranceCreationDate,
    uint insuranceExpiration
  );

  struct InsuranceInfo {
    address insuredUser;
    uint currentPrice;
    uint insuredAmount;
    uint percentageCoverage;
    uint insuranceCreationDate;
    uint insuranceExpirationDate;
    bool finished;
  }

  uint public s_lastPrice;
  uint8 decimals = 8;

  uint256[3] s_monthPremiums = [30, 50, 70]; // USD per ETH insured
  uint256[3] s_percentageCoverage = [10, 20, 30];

  uint256 s_insuranceIndexEnd = 1;
  uint256 public s_insuranceIndexStart = 1;
  uint256[] public s_insuranceIndexs;

  // index of insurance to insurance info
  mapping(uint256 => InsuranceInfo) public s_insurances;

  mapping(address => uint256) public balanceOf;

  modifier checkMonths(uint8 _months) {
    if (_months == 0 || _months > 3) {
      revert WrongMonthAmountInsurance();
    }
    _;
  }

  modifier checkFunds(address user) {
    if (balanceOf[user] == 0) {
      revert NoFundsToWithdraw();
    }
    _;
  }

  constructor() {
    s_insuranceIndexs.push(0);
    priceFeed = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306); // Address ETH/USD

    // Erase below
    (, int price, , , ) = priceFeed.latestRoundData();
    price = price / int(10 ** decimals);
    uint roundedPrice = uint(price);
    s_lastPrice = roundedPrice;
  }

  function requestQuote(uint _amount, uint8 _monthsCoverage) public view checkMonths(_monthsCoverage) returns (uint) {
    uint256 premiumToPayUSD = (s_monthPremiums[_monthsCoverage - 1] * _amount) / (10 ** 18);
    uint256 premiumToPayWei = ((premiumToPayUSD * 10 ** 8) / (s_lastPrice)) * 10 ** 10;
    return premiumToPayWei;
  }

  function createInsurance(uint _amount, uint8 _monthsCoverage) external payable checkMonths(_monthsCoverage) {
    uint256 premiumToPay = requestQuote(_amount, _monthsCoverage);
    require(msg.value == premiumToPay, "Wrong amount funded");

    InsuranceInfo memory newInsurance = InsuranceInfo({
      insuredUser: msg.sender,
      currentPrice: s_lastPrice,
      insuredAmount: _amount,
      percentageCoverage: s_percentageCoverage[_monthsCoverage - 1],
      insuranceCreationDate: block.timestamp,
      insuranceExpirationDate: block.timestamp + _monthsCoverage * 1 minutes, //block.timestamp + (_monthsCoverage * 30 days),
      finished: false
    });

    s_insurances[s_insuranceIndexEnd] = newInsurance;
    s_insuranceIndexs.push(s_insuranceIndexEnd);
    unchecked {
      s_insuranceIndexEnd++;
    }

    emit InsuranceCreation(
      msg.sender,
      _amount,
      s_percentageCoverage[_monthsCoverage - 1],
      premiumToPay,
      block.timestamp,
      block.timestamp + (_monthsCoverage * 30 days)
    );
  }

  function insuranceExpirationCheck() external {
    bool beggining = true;
    for (uint256 i = s_insuranceIndexStart; i < s_insuranceIndexEnd; i++) {
      if (s_insuranceIndexs[i] != 0) {
        beggining = false;
        if (
          s_insurances[s_insuranceIndexs[i]].finished == false &&
          s_insurances[s_insuranceIndexs[i]].insuranceExpirationDate < block.timestamp
        ) {
          InsuranceInfo memory expiredInsurance = s_insurances[s_insuranceIndexs[i]];
          uint minPriceToCover = (expiredInsurance.currentPrice * (100 - expiredInsurance.percentageCoverage)) / 100;
          if (s_lastPrice < minPriceToCover) {
            uint amountToPayUSD = minPriceToCover - s_lastPrice;
            balanceOf[expiredInsurance.insuredUser] = ((amountToPayUSD * 10 ** 8) / s_lastPrice) * 10 ** 10;
          }
          s_insurances[s_insuranceIndexs[i]].finished = true;
          delete (s_insuranceIndexs[i]);
        }
      } else if (beggining == true) {
        s_insuranceIndexStart = i;
      }
    }
  }

  function withdrawInsuredFunds() public checkFunds(msg.sender) nonReentrant {
    (bool success, ) = msg.sender.call{value: balanceOf[msg.sender]}("");
    require(success, "Transaction failed");
    balanceOf[msg.sender] = 0;
  }

  function setPrice(uint _newPrice) public {
    s_lastPrice = _newPrice;
  }

  function getLatestPrice() public {
    (, int price, , , ) = priceFeed.latestRoundData();
    price = price / int(10 ** decimals);
    uint roundedPrice = uint(price);
    s_lastPrice = roundedPrice;
  }

  function getBalance() public view returns (uint) {
    return address(this).balance;
  }
}
