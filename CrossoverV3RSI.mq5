#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>

//Input Variables
input group "=== Indicators ==="
input int fastMA = 6;
input int slowMA = 85;
input int rsiPeriod = 14;
input int rsiLow = 40;
input int rsiHigh = 60;

input group "=== Stop loss and take profit (in points)"
input int SL = 100;     //Stop loss
input int TP = 200;     //Take profit

input group "=== Risk management ==="
input double percentRisk = 1.0;    //Risk in percentage

//Global Variables
int fastHandle;
int slowHandle;
int rsiHandle;
double fastBuffer[];
double slowBuffer[];
double rsiBuffer[];
datetime openTimeBuy = 0;
datetime openTimeSell = 0;
CTrade trade;

//Expert initialization function
int OnInit() 
{
   if(percentRisk <= 0)
   {
      Alert("Invalid lot size");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   if(fastMA <= 0)
   {
      Alert("Invalid fast MA");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   if(slowMA <= 0)
   {
      Alert("Invalid slow MA");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   if(rsiPeriod <= 1)
   {
      Alert("Invalid RSI period");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   if(rsiHigh < 50)
   {
      Alert("Invalid upper RSI limit");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   if(rsiLow > 50)
   {
      Alert("Invalid lower RSI limit");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   if(rsiHigh < rsiLow)
   {
      Alert("RSI upper limit is less than lower limit");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   if(SL <= 0)
   {
      Alert("Invalid SL");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   if(TP <= 0)
   {
      Alert("Invalid TP");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   if(fastMA >= slowMA)
   {
      Alert("Fast MA is greater than slow MA");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   fastHandle = iMA(_Symbol, PERIOD_CURRENT, fastMA, 0, MODE_SMA, PRICE_CLOSE);
   if(fastHandle == INVALID_HANDLE)
   {
      Alert("Fast handle failure");
      return INIT_FAILED;
   }
   
   slowHandle = iMA(_Symbol, PERIOD_CURRENT, slowMA, 0, MODE_SMA, PRICE_CLOSE);
   if(slowHandle == INVALID_HANDLE)
   {
      Alert("Slow handle failure");
      return INIT_FAILED;
   }
   
   rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, rsiPeriod, PRICE_CLOSE);
   if(rsiHandle == INVALID_HANDLE)
   {
      Alert("RSI handle failure");
      return INIT_FAILED;
   }
   
   ArraySetAsSeries(fastBuffer, true);
   ArraySetAsSeries(slowBuffer, true);
   ArraySetAsSeries(rsiBuffer, true);
   
   return(INIT_SUCCEEDED);
}

//Expert deinitialization function
void OnDeinit(const int reason)
{
   if(fastHandle != INVALID_HANDLE)
   {
      IndicatorRelease(fastHandle);
   }
   
   if(slowHandle != INVALID_HANDLE)
   {
      IndicatorRelease(slowHandle);
   }
   
   if(rsiHandle != INVALID_HANDLE)
   {
      IndicatorRelease(rsiHandle);
   }
}

//Calculate Lots
bool CalculateLots(double SlForCalc, double &lotCalc)
{
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double volumeStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * percentRisk * 0.01;
   double moneyVolumeStep = (SlForCalc / tickSize) * tickValue * volumeStep;
   
   lotCalc = (riskMoney / moneyVolumeStep) * volumeStep;
   
   if(!CheckLots(lotCalc))
   {
      return false;
   }
      
   return true;
}

//Check Lots
bool CheckLots(double &lots)
{
   double min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   if(lots < min)
   {
      Print("Lot: ", lots, " lower than minimum allowed: ", min);
      return false;
   }
   else if(lots > max)
   {
      Print("Lot: ", lots, " higher than maximum allowed: ", max);
      return false;
   }
   
   lots = (int)MathFloor(lots/step) * step;
   return true;
}

//Expert tick function
void OnTick(){
   int values = CopyBuffer(fastHandle, 0, 0, 2, fastBuffer);
   if(values != 2){
      Print("Not enough data for fast MA");
      return;
   }
   
   values = CopyBuffer(slowHandle, 0, 0, 2, slowBuffer);
   if(values != 2){
      Print("Not enough data for slow MA");
      return;
   }
   
   values = CopyBuffer(rsiHandle, 0, 0, 2, rsiBuffer);
   if(values != 2){
      Print("Not enough data for RSI");
      return;
   }
   
   if(fastBuffer[1] <= slowBuffer[1] && fastBuffer[0] > slowBuffer[0] && rsiBuffer[0] > rsiHigh && openTimeBuy != iTime(_Symbol, PERIOD_CURRENT, 0))
   {
      
      openTimeBuy = iTime(_Symbol, PERIOD_CURRENT, 0);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl = ask - SL * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double tp = ask + TP * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      double SlForCalc = ask - sl;
      double lotSize;
      
      if(CalculateLots(SlForCalc, lotSize)){
         trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, lotSize, ask, sl, tp, "Buy trade taken");
      }
   }
   
   if(fastBuffer[1] >= slowBuffer[1] && fastBuffer[0] < slowBuffer[0] && rsiBuffer[0] < rsiLow && openTimeSell != iTime(_Symbol, PERIOD_CURRENT, 0))
   {
      openTimeSell = iTime(_Symbol, PERIOD_CURRENT, 0);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl = bid + SL * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double tp = bid - TP * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      double SlForCalc = bid + sl;
      double lotSize;
      
      if(CalculateLots(SlForCalc, lotSize)){
         trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, lotSize, bid, sl, tp, "Sell trade taken");
      }
   }
}