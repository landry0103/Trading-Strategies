# PSAR (Parabolic Stop And Reverse) trading strategy backtest - Copyright(C) 2023 Centrabit.com ( Author: smartalina0915@gmail.com )

# Script Name
script PSARBackTest;

# System Libraries
import IO;
import Time;
import Trades;
import Charts;
import Math;
import Processes;

# Built-in Library
import "library.csh";

#############################################
# User settings
string  EXCHANGESETTING = "Centrabit";
string  SYMBOLSETTING   = "LTC/BTC";
float   AFINIT          = 0.02;
float   AFMAX           = 0.2;
float   AFSTEP          = 0.02;
string  RESOL           = "1d";                     # Bar resolution
float   BALANCE         = 100.0;                    # Backtest Balance
float   AMOUNT          = 10.0;                     # The amount of buy or sell order at once
string  STARTDATETIME   = "2023-07-01 00:00:00";    # Backtest start datetime
string  ENDDATETIME     = "now";                    # Backtest end datetime
float   EXPECTANCYBASE  = 0.1;                      # expectancy base
float   FEE             = 0.002;                    # trading fee as a decimal (0.2%)
#############################################

# Trading Variables
string  trend;                                      # "", "up", "down"
float   highs[];
float   lows[];
float   psar;
float   ep              = 0.0;
float   af              = AFINIT;
integer currentOrderId  = 0;
integer buyCount        = 0;
integer sellCount       = 0;
integer winCount        = 0;
integer lossCount       = 0;
float   totalProfit     = 0.0;
float   buyTotal        = 0.0;
float   sellTotal       = 0.0;
float   totalWin        = 0.0;
float   totalLoss       = 0.0;
float   feeTotal        = 0.0;
float   entryAmount     = 0.0;
float   entryFee        = 0.0;
string  tradeLogList[];
float   baseCurrencyBalance   = getAvailableBalance(EXCHANGESETTING, getBaseCurrencyName(SYMBOLSETTING));
float   quoteCurrencyBalance  = getAvailableBalance(EXCHANGESETTING, getQuoteCurrencyName(SYMBOLSETTING));

# Additional needs in backtest mode
float   minFillOrderPercentage = 0.0;
float   maxFillOrderPercentage = 0.0;

boolean reversed;

bar barData[];
integer resolution = interpretResol(RESOL);
integer barSize = resolution * 60 * 1000 * 1000;

integer profitSeriesID = 0;
string profitSeriesColor = "green";
transaction currentTran;
transaction entryTran;

void initCommonParameters() {
  if (toBoolean(getVariable("EXCHANGE"))) 
    EXCHANGESETTING = getVariable("EXCHANGE");
  if (toBoolean(getVariable("CURRNCYPAIR"))) 
    SYMBOLSETTING = getVariable("CURRNCYPAIR");
  if (toBoolean(getVariable("RESOLUTION"))) 
    RESOL = getVariable("RESOLUTION");
  if (toBoolean(getVariable("AMOUNT"))) 
    AMOUNT = toFloat(getVariable("AMOUNT"));
  if (toBoolean(getVariable("STARTDATETIME"))) 
    STARTDATETIME = getVariable("STARTDATETIME");
  if (toBoolean(getVariable("ENDDATETIME"))) 
    ENDDATETIME = getVariable("ENDDATETIME");
  if (toBoolean(getVariable("EXPECTANCYBASE"))) 
    EXPECTANCYBASE = toFloat(getVariable("EXPECTANCYBASE"));
}

void saveResultToEnv(string accProfit, string expectancy) {
  setVariable("ACCPROFIT", accProfit);
  setVariable("EXPECTANCY", expectancy);  
}

void onOwnOrderFilledTest(transaction t) {
  float amount = t.price * t.amount;
  feeTotal += t.fee;

  if (t.isAsk == false) {                # when sell order fillend
    sellTotal += amount;
    baseCurrencyBalance -= AMOUNT;
    BALANCE -= AMOUNT;
    quoteCurrencyBalance += amount;
  } else {                                 # when buy order fillend
    buyTotal += amount;
    baseCurrencyBalance += AMOUNT;
    BALANCE += AMOUNT;
    quoteCurrencyBalance -= amount;
  }

  integer isOddOrder = t.marker % 2;
  integer tradeNumber = (t.marker-1) / 2 + 1;
  string tradeLog = "   ";

  if (isOddOrder == 0) {
    print(toString(t.marker) + " filled (" + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + ") : " + toString(t.price) + " * " + toString(t.amount) + ",  fee: " + toString(t.fee) + ",  Total profit: " + toString(sellTotal - buyTotal - feeTotal));
    string tradeNumStr = toString(tradeNumber);
    for (integer i = 0; i < strlength(tradeNumStr); i++) {
      tradeLog += " ";
    }
    float profit;
    if (t.isAsk == false) {
      profit = amount - entryAmount - t.fee - entryFee;
      tradeLog += "\tLX\t";
    } else {
      profit = entryAmount - amount - t.fee - entryFee;
      tradeLog += "\tSX\t";
    }

    tradeLog = tradeLog + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + "\t" + toString(t.price) + "\t\t" + toString(t.amount) + "\t" + toString(profit) + "  \t" + toString(sellTotal - buyTotal - feeTotal);

    string tradeResult;
    if (profit >= 0.0 ) {
      totalWin += profit;
      winCount++;
      if (profitSeriesColor=="red") {
        profitSeriesColor="green";
      }
    } else {
      totalLoss+= fabs(profit);
      lossCount++;
      if (profitSeriesColor == "green") {
        profitSeriesColor="red";
      }
    }
    tradeLogList >> tradeLog;

    totalProfit += profit;

    profitSeriesID++;
    setCurrentChartPosition("0");
    setCurrentSeriesName("Direction" + toString(profitSeriesID));
    configureLine(false, profitSeriesColor, 2.0);
    drawChartPoint(entryTran.tradeTime, entryTran.price);
    drawChartPoint(currentTran.tradeTime, currentTran.price);
    # print(totalProfit);

    setCurrentChartPosition("1");
    setCurrentSeriesName("Balance");
    drawChartPoint(currentTran.tradeTime, BALANCE + totalProfit);
    setCurrentSeriesName("Change");
    drawChartPoint(currentTran.tradeTime, BALANCE + totalProfit);
    entryTran = currentTran;
  } else {
    print(toString(t.marker) + " filled (" + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + ") : " + toString(t.price) + " * " + toString(t.amount) + ",  fee: " + toString(t.fee));
    tradeLog += toString(tradeNumber);
    if (t.isAsk == false) {
      tradeLog += "\tSE\t";
    } else {
      tradeLog += "\tLE\t";
    }
    entryAmount = amount;
    entryFee = t.fee;

    if (tradeNumber == 1) {
      tradeLog = tradeLog + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + "\t" + toString(t.price) + "\t" + toString(AMOUNT / 2.0);
    } else {
      tradeLog = tradeLog + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + "\t" + toString(t.price) + "\t\t" + toString(AMOUNT);
    }

    tradeLogList >> tradeLog;

    entryTran = currentTran;

    setCurrentChartPosition("1");
    setCurrentSeriesName("Balance");
    drawChartPoint(currentTran.tradeTime, BALANCE);
    setCurrentSeriesName("Change");
    drawChartPoint(currentTran.tradeTime, BALANCE);
  }
}

void onTimeOutTest(integer i) {
  float highest;
  float lowest;

  string oldTrend = trend;

  if (trend == "up") {              # while upward trending 
    # Calculate the new PSAR
    psar = psar + af * ( ep - psar);
    # Ensure the latest PSAR value is as low or lower than the low price of the past two days
    lowest = fmin(lows[0], lows[1]);
    psar = fmin(psar, lowest);

    # Add the latest prices to the current trend list
    delete highs[0];
    delete lows[0];
    highs >> barData[i].highPrice;
    lows >> barData[i].lowPrice;

    # check for a trend reversal
    if (psar <= lows[1]) {
      trend = "up";
      reversed = false;
    } else {
      psar = fmax(highs[0], highs[1]);
      trend = "down";
      reversed = true;
    }

    # Update the extreme point and af
    if (reversed == true) {
      ep = lows[1];
      af = AFINIT;
    } else if (highs[1] > ep) {
      ep = highs[1];
      af = fmin(af+AFSTEP, AFMAX);
    }
  } else {                          # while downward trending
    # Calculate the new PSAR
    psar = psar - af * ( psar - ep);
    # Ensure the latest PSAR value is as low or lower than the low price of the past two days
    highest = fmax(highs[0], highs[1]);
    psar = fmax(psar, highest);

    # Add the latest prices to the current trend list
    delete highs[0];
    delete lows[0];
    highs >> barData[i].highPrice;
    lows >> barData[i].lowPrice;

    # check for a trend reversal
    if (psar >= highs[1]) {
      trend = "down";
      reversed = false;
    } else {
      psar = fmin(lows[0], lows[1]);
      trend = "up";
      reversed = true;
    }

    # Update the extreme point and af
    if (reversed == true) {
      ep = highs[1];
      af = AFINIT;
    } else if (lows[1] < ep) {
      ep = lows[1];
      af = fmin(af+AFSTEP, AFMAX);
    }
  }

  transaction barTransactions[] = getPubTrades(EXCHANGESETTING, SYMBOLSETTING, barData[i].timestamp, barData[i].timestamp+barSize);
  currentTran = barTransactions[0];
  transaction t;

  if (trend == "up") {
    setCurrentChartPosition("0");
    drawChartPointToSeries("Upward", barData[i].timestamp, psar);
    if (oldTrend != "up") {
      currentOrderId++;
      print(toString(currentOrderId) + " buy order (" + timeToString(currentTran.tradeTime, "yyyy-MM-dd hh:mm:ss") + ") : " + "base price: " + toString(currentTran.price) + "  amount: "+ toString(AMOUNT));
      t.id = currentOrderId;
      t.marker = currentOrderId;
      t.price = currentTran.price + currentTran.price * randomf((1.0-minFillOrderPercentage), (1.0-maxFillOrderPercentage));
      t.amount = AMOUNT;
      t.fee = AMOUNT*t.price*FEE * 0.01;
      t.tradeTime = currentTran.tradeTime;
      t.isAsk = true;
      onOwnOrderFilledTest(t);
      buyCount++;
      setCurrentChartPosition("0");
      drawChartPointToSeries("Buy", currentTran.tradeTime, currentTran.price);      
    }
  } else {
    setCurrentChartPosition("0");
    drawChartPointToSeries("Downward", barData[i].timestamp, psar);
    if (oldTrend != "down") {
      currentOrderId++;
      print(toString(currentOrderId) + " sell order (" + timeToString(currentTran.tradeTime, "yyyy-MM-dd hh:mm:ss") + ") : " + "base price: " + toString(currentTran.price) + "  amount: "+ toString(AMOUNT));
      t.id = currentOrderId;
      t.marker = currentOrderId;
      t.price = currentTran.price * randomf(minFillOrderPercentage, maxFillOrderPercentage);
      t.amount = AMOUNT;
      t.fee = AMOUNT*t.price*FEE * 0.01;
      t.tradeTime = currentTran.tradeTime;
      t.isAsk = false;
      onOwnOrderFilledTest(t);
      sellCount++;
      setCurrentChartPosition("0");
      drawChartPointToSeries("Sell", currentTran.tradeTime, currentTran.price);
    }
  }
}

void backtest() {
  initCommonParameters();

  print("^^^^^^^^^^^^^^^^^ ParabolicSAR Backtest ( EXCHANGE : " + EXCHANGESETTING + ", CURRENCY PAIR : " + SYMBOLSETTING + ") ^^^^^^^^^^^^^^^^^");
  print("");

  print(STARTDATETIME + " to " + ENDDATETIME);

  # Connection Checking
  integer conTestStartTime = getCurrentTime() - 60 * 60 * 1000000;           # 1 hour before
  integer conTestEndTime = getCurrentTime();
  transaction conTestTrans[] = getPubTrades(EXCHANGESETTING, SYMBOLSETTING, conTestStartTime, conTestEndTime);
  if (sizeof(conTestTrans) == 0) {
    print("Fetching Data failed. Please check the connection and try again later");
    exit;
  }

  # Fetching the historical trading data of given datatime period
  integer testStartTime = stringToTime(STARTDATETIME, "yyyy-MM-dd hh:mm:ss");
  integer testEndTime;

  integer currentTime = getCurrentTime();
  if (ENDDATETIME == "now") {
    testEndTime = currentTime;
  } else {
    testEndTime = stringToTime(ENDDATETIME, "yyyy-MM-dd hh:mm:ss");
  }

  # Checking Maximum Back Test Period
  integer testTimeLength = testEndTime - testStartTime;
  if (testTimeLength > 31536000000000) { # maximum backtest available length is 1 year = 365  * 24 * 60 * 60 * 1000000 ns
    print("You exceeded the maximum backtest period.\nPlease try again with another STARTDATETIME setting");
    return;
  }

  integer barCnt = testTimeLength / barSize + 3;
  barData = getTimeBars(EXCHANGESETTING, SYMBOLSETTING, testEndTime, barCnt, barSize);
  if (sizeof(barData) == 0) {
    print("Lookback bar data fetching failed! " + toString(sizeof(barData)) + " fetched.");
    return;
  }

  if (barData[1].highPrice >= barData[0].highPrice) {
    trend = "up";       # the trend of the day before
  } else {
    trend = "down";
  }

  # PSAR initialization
  highs >> barData[1].highPrice;
  highs >> barData[2].highPrice;
  lows >> barData[1].lowPrice;
  lows >> barData[2].lowPrice;

  reversed = false;

  if (trend == "up") {
    psar = fmin(lows[0], lows[1]);
    ep = fmax(highs[0], highs[1]);
    if (highs[1] > psar) {
      trend = "up";
      reversed = false;
    } else {
      trend = "down";
      reversed = true;
    }
  } else {
    trend = "down";  
    psar = fmax(highs[0], highs[1]);
    ep = fmin(lows[0], lows[1]);
    if (lows[1] < psar) {
      trend = "down";
      reversed = false;
    } else {
      trend = "up";
      reversed = true;
    }
  }

  setCurrentChartsExchange(EXCHANGESETTING);
  setCurrentChartsSymbol(SYMBOLSETTING);
  clearCharts();

  setChartBarWidth(barSize);
  setChartTime(barData[0].timestamp +  777600000000); # 10min * 9

  setChartDataTitle("PSAR - " + toString(AFINIT) + ", " + toString(AFMAX) + ", " + toString(AFSTEP));

  setCurrentSeriesName("Sell");
  configureScatter(true, "red", "red", 7.0);
  setCurrentSeriesName("Buy");
  configureScatter(true, "#7dfd63", "#187206", 7.0);
  setCurrentSeriesName("Upward");
  configureScatter(true, "#faf849", "#6d6c0d", 7.0);
  setCurrentSeriesName("Downward");
  configureScatter(true, "#6beafd", "#095b67", 7.0);
  setCurrentSeriesName("Direction");
  configureLine(true, "green", 2.0);

  setCurrentChartPosition("1");
  setChartDataTitle(getBaseCurrencyName(SYMBOLSETTING) + " Balance");
  setChartYRange(0.0, 200.0); 
  setCurrentSeriesName("Balance");
  configureLine(true, "green", 2.0);
  setCurrentSeriesName("Change");
  configureScatter(true, "red", "red", 7.0);
  

  float minAskOrderPrice = getOrderBookAsk(EXCHANGESETTING, SYMBOLSETTING);
  float maxBidOrderPrice = getOrderBookBid(EXCHANGESETTING, SYMBOLSETTING);

  order askOrders[] = getOrderBookByRangeAsks(EXCHANGESETTING, SYMBOLSETTING, 0.0, 1.0);
  order bidOrders[] = getOrderBookByRangeBids(EXCHANGESETTING, SYMBOLSETTING, 0.0, 1.0);


  minFillOrderPercentage = bidOrders[0].price/askOrders[sizeof(askOrders)-1].price;
  maxFillOrderPercentage = bidOrders[sizeof(bidOrders)-1].price/askOrders[0].price;
  if (AMOUNT < 10.0) {
    minFillOrderPercentage = maxFillOrderPercentage * 0.999;
  } else if (AMOUNT <100.0) {
    minFillOrderPercentage = maxFillOrderPercentage * 0.998;
  } else if (AMOUNT < 1000.0) {
    minFillOrderPercentage = maxFillOrderPercentage * 0.997;
  } else {
    minFillOrderPercentage = maxFillOrderPercentage * 0.997;
  }

  currentOrderId = 0;

  setCurrentChartPosition("0");
  if (trend == "up") {
    drawChartPointToSeries("Upward", barData[2].timestamp, psar);
  } else {
    drawChartPointToSeries("Downward", barData[2].timestamp, psar);
  }

  setCurrentChartPosition("1");
  setCurrentSeriesName("Balance");
  drawChartPoint(barData[2].timestamp, BALANCE);

  integer msleepFlag = 0;
  integer shouldBePositionClosed;

  setChartsPairBuffering(true);

  for (integer i = 3; i < sizeof(barData); i++) {
    onTimeOutTest(i);
    if (i == sizeof(barData)-1) {
      shouldBePositionClosed = currentOrderId % 2;
      if ((shouldBePositionClosed == 1)) {
        transaction barTransactions[] = getPubTrades(EXCHANGESETTING, SYMBOLSETTING, barData[i].timestamp, barData[i].timestamp+barSize);
        currentTran = barTransactions[0];
        transaction t;

        if (trend == "down") {
          currentOrderId++;
          if (currentOrderId == 1) {
            print(toString(currentOrderId) + " buy order (" + timeToString(currentTran.tradeTime, "yyyy-MM-dd hh:mm:ss") + ") : " + "base price " + toString(currentTran.price) + "  amount: "+ toString(AMOUNT / 2.0));
          } else {
            print(toString(currentOrderId) + " buy order (" + timeToString(currentTran.tradeTime, "yyyy-MM-dd hh:mm:ss") + ") : " + "base price " + toString(currentTran.price) + "  amount: "+ toString(AMOUNT));
          }

          t.id = currentOrderId;
          t.marker = currentOrderId;
          t.price = currentTran.price + currentTran.price * randomf((1.0-minFillOrderPercentage), (1.0-maxFillOrderPercentage));
          if (currentOrderId == 1) {
            t.amount = AMOUNT / 2.0;
            t.fee = AMOUNT / 2.0 * t.price * FEE * 0.01;
          } else {
            t.amount = AMOUNT;
            t.fee = AMOUNT * t.price * FEE * 0.01;
          }
          t.tradeTime = currentTran.tradeTime;
          t.isAsk = true;
          onOwnOrderFilledTest(t);
          buyCount++;
          setCurrentChartPosition("0");
          drawChartPointToSeries("Buy", currentTran.tradeTime, currentTran.price);      
        } 
        else {
          currentOrderId++;
          if (currentOrderId == 1) {
            print(toString(currentOrderId) + " sell order (" + timeToString(currentTran.tradeTime, "yyyy-MM-dd hh:mm:ss") + ") : " + "base price " + toString(currentTran.price) + "  amount: "+ toString(AMOUNT / 2.0));
          } else {
            print(toString(currentOrderId) + " sell order (" + timeToString(currentTran.tradeTime, "yyyy-MM-dd hh:mm:ss") + ") : " + "base price " + toString(currentTran.price) + "  amount: "+ toString(AMOUNT));
          }
          t.id = currentOrderId;
          t.marker = currentOrderId;
          t.price = currentTran.price * randomf(minFillOrderPercentage, maxFillOrderPercentage);
          if (currentOrderId == 1) {
            t.amount = AMOUNT / 2.0;
            t.fee = AMOUNT / 2.0 * t.price * FEE * 0.01;
          } else {
            t.amount = AMOUNT;
            t.fee = AMOUNT * t.price * FEE * 0.01;
          }
          t.tradeTime = currentTran.tradeTime;
          t.isAsk = false;
          onOwnOrderFilledTest(t);
          sellCount++;
          setCurrentChartPosition("0");
          drawChartPointToSeries("Sell", currentTran.tradeTime, currentTran.price);
        }
      }
    }

    msleepFlag = i % 2000;
    if ( msleepFlag == 0) {
      msleep(20);
    }  
  }

  setChartsPairBuffering(false);

  float rewardToRiskRatio = totalWin / totalLoss;
  float winLossRatio = toFloat(winCount) / toFloat(lossCount);
  float winRatio = toFloat(winCount) / toFloat(winCount+lossCount);
  float lossRatio = toFloat(lossCount) / toFloat(winCount+lossCount);
  float expectancyRatio = rewardToRiskRatio * winRatio - lossRatio;

  float averageWin = totalWin / toFloat(winCount);
  float averageLoss = totalLoss / toFloat(lossCount);
  integer totalCount = winCount + lossCount;
  float winPercentage = toFloat(winCount) / toFloat(totalCount);
  float lossPercentage = toFloat(lossCount) / toFloat(totalCount);

  float tharpExpectancy = ((winPercentage * averageWin) - (lossPercentage * averageLoss) ) / (averageLoss);

  string resultString;
  if (tharpExpectancy < EXPECTANCYBASE) {
    resultString = "FAIL";
  } else {
    resultString = "PASS";
  }

  print("");
  
  string tradeListTitle = "\tTrade\tTime";
  tradeListTitle = strinsert(tradeListTitle, strlength(tradeListTitle), "\t\t");
  tradeListTitle = strinsert(tradeListTitle, strlength(tradeListTitle), SYMBOLSETTING);
  tradeListTitle = strinsert(tradeListTitle, strlength(tradeListTitle), "\tMax");
  tradeListTitle = strinsert(tradeListTitle, strlength(tradeListTitle), getBaseCurrencyName(SYMBOLSETTING));
  tradeListTitle = strinsert(tradeListTitle, strlength(tradeListTitle), "\tProf");
  tradeListTitle = strinsert(tradeListTitle, strlength(tradeListTitle), getQuoteCurrencyName(SYMBOLSETTING));
  tradeListTitle = strinsert(tradeListTitle, strlength(tradeListTitle), "\tAcc\tDrawdown");

  print("--------------------------------------------------------------------------------------------------------------------------");
  print(tradeListTitle);
  print("--------------------------------------------------------------------------------------------------------------------------");
  for (integer i = 0; i < sizeof(tradeLogList); i++) {
    print(tradeLogList[i]);
  }
  print(" ");
  print("--------------------------------------------------------------------------------------------------------------------------");
  print("Reward-to-Risk Ratio : " + toString(rewardToRiskRatio));
  print("Win/Loss Ratio : " + toString(winLossRatio));
  print("Win Ratio  : " + toString(winRatio));
  print("Loss Ratio : " + toString(lossRatio));
  print("Expectancy : " + toString(tharpExpectancy));
  print("@ Expectancy Base: " + toString(EXPECTANCYBASE));
  print(" ");
  print("Result : " + resultString);

  print("Total profit : " + toString(sellTotal - buyTotal - feeTotal));
  print("*****************************");

  saveResultToEnv(toString(sellTotal - buyTotal - feeTotal), toString(tharpExpectancy));
}

backtest();