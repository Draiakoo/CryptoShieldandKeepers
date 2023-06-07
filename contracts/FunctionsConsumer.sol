// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {Functions, FunctionsClient} from "./dev/functions/FunctionsClient.sol";   // Delete this line if you run this smart contract outside the chainlink functions hardhat kit and discomment the line below
// import "@chainlink/contracts/src/v0.8/dev/functions/FunctionsClient.sol";      // Discomment this when you are going to deploy this smart contract outside the chainlink functions kit 
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";

contract FunctionsConsumer is FunctionsClient, ConfirmedOwner, AutomationCompatibleInterface {
  using Functions for Functions.Request;

  AggregatorV3Interface internal priceFeedETH;

  struct InsuranceData {
    uint256 highPricePrediction;
    uint256 lowPricePrediction;
    uint256 closePricePrediction;
    uint256 highRisk;
    uint256 lowRisk;
    uint256 closeRisk;
  }

  // this struct will be private, but it is public for testing
  InsuranceData public dailyData;

  uint64 public constant c_subscriptionId = 387;
  uint32 public constant c_gasLimit = 300000;

  bool public fetching = true;

  Functions.Request public s_request;

  uint public constant INTERVAL = 1 days;
  uint public lastTimeStamp;

  event OCRResponse(bytes32 indexed requestId, bytes result, bytes err);

  constructor(address oracle) FunctionsClient(oracle) ConfirmedOwner(msg.sender) {
    priceFeedETH = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306); // Address ETH/USD
  }

  // this function is just used to test so it will not be in the final code. It was used to reset the data to see if the keeper actually makes the request.
  function resetStruct() public {
    dailyData.highPricePrediction = 0;
    dailyData.lowPricePrediction = 0;
    dailyData.closePricePrediction = 0;
    dailyData.highRisk = 0;
    dailyData.lowRisk = 0;
    dailyData.closeRisk = 0;
  }

  // this function is what the chainlink keeper checks before executing performUpkeep. It just looks if it has passed 1 day before last timestamp
  function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool upkeepNeeded, bytes memory /* performData */){
    upkeepNeeded = (block.timestamp - lastTimeStamp) > INTERVAL;
  }

  // this function is what chainlink keepers execute once a day has passed. It only executes a request to get the data from our api
  function performUpkeep(bytes calldata /* performData */) external override {
    if ((block.timestamp - lastTimeStamp) > INTERVAL) {
      lastTimeStamp = block.timestamp;
      fetchDailyData();
    }
  }

  /// this is the only function to get the data from our server. I change it to 1 function because it now gets all 6 data
  function fetchDailyData() public {
    Functions.Request memory req;
    req = s_request;
    sendRequest(req, c_subscriptionId, c_gasLimit);
    fetching = true;
  }

  // this function is the calculations that you want to make and you will have all the 6 data inside the dailyData struct. This function can't be called when the request to get the data is still being fetched.
  function getQuote() public view returns(uint256){
    require(!fetching, "Daily data is being fetched");
    // here do the calculations. Access the data inside the struct dailyData
    return(uint256(394));
  }

  /// @notice do NOT use this function, it is used to initialize the requests
  function executeRequest(
    string memory source,
    bytes memory secrets,
    string[] memory args,
    uint64 subscriptionId,
    uint32 gasLimit
  ) public returns (bytes32) {
    Functions.Request memory req;
    req.initializeRequest(Functions.Location.Inline, Functions.CodeLanguage.JavaScript, source);
    s_request = req;
    if (secrets.length > 0) {
      req.addRemoteSecrets(secrets);
    }
    if (args.length > 0) req.addArgs(args);

    bytes32 assignedReqID = sendRequest(req, subscriptionId, gasLimit);
    return assignedReqID;
  }

  /// @notice callback function called by the chainlink nodes once they have fetched the information requested.
  ///       You can write the code to execute once the requested date has been received inside the if conditionals
  function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
    (dailyData.highPricePrediction, dailyData.lowPricePrediction, dailyData.closePricePrediction, dailyData.highRisk, dailyData.lowRisk, dailyData.closeRisk) = abi.decode(response, (uint256, uint256, uint256, uint256, uint256, uint256));
    fetching = false;
    emit OCRResponse(requestId, response, err);
  }

  /// @notice Function to retrieve the ETH/USD price from chainlink price feed
  function getLatestPriceETH() public view returns (int256) {
    (, int price, , , ) = priceFeedETH.latestRoundData();
    return price;
  }

  function updateOracleAddress(address oracle) public onlyOwner {
    setOracle(oracle);
  }

  function addSimulatedRequestId(address oracleAddress, bytes32 requestId) public onlyOwner {
    addExternalRequest(oracleAddress, requestId);
  }
}
