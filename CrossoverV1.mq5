#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>

//Input Variables
input int fastMA = 7;
input int slowMA = 85;
input int SL = 100;
input int TP = 200;

//Global Variables
int fastHandle;
int slowHandle;
double fastBuffer[];
double slowBuffer[];
datetime openTimeBuy = 0;
datetime openTimeSell = 0;
CTrade trade;

//Expert initialization function
int OnInit() {
   if(fastMA <= 0){
      Alert("Invalid fast MA");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   if(slowMA <= 0){
      Alert("Invalid slow MA");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   if(SL <= 0){
      Alert("Invalid SL");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   if(TP <= 0){
      Alert("Invalid TP");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   if(fastMA >= slowMA){
      Alert("Fast MA is greater than slow MA");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   fastHandle = iMA(_Symbol, PERIOD_CURRENT, fastMA, 0, MODE_SMA, PRICE_CLOSE);
   if(fastHandle == INVALID_HANDLE){
      Alert("Fast handle failure");
      return INIT_FAILED;
   }
   
   slowHandle = iMA(_Symbol, PERIOD_CURRENT, slowMA, 0, MODE_SMA, PRICE_CLOSE);
   if(slowHandle == INVALID_HANDLE){
      Alert("Slow handle failure");
      return INIT_FAILED;
   }
   
   ArraySetAsSeries(fastBuffer, true);
   ArraySetAsSeries(slowBuffer, true);
   
   return(INIT_SUCCEEDED);
}

//Expert deinitialization function
void OnDeinit(const int reason){
   if(fastHandle != INVALID_HANDLE){
      IndicatorRelease(fastHandle);
   }
   
   if(slowHandle != INVALID_HANDLE){
      IndicatorRelease(slowHandle);
   }
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
   
   if(fastBuffer[1] <= slowBuffer[1] && fastBuffer[0] > slowBuffer[0] && openTimeBuy != iTime(_Symbol, PERIOD_CURRENT, 0)){
      
      openTimeBuy = iTime(_Symbol, PERIOD_CURRENT, 0);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl = ask - SL * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double tp = ask + TP * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, 1.0, ask, sl, tp, "Trade taken");
   }
   
   if(fastBuffer[1] >= slowBuffer[1] && fastBuffer[0] < slowBuffer[0] && openTimeSell != iTime(_Symbol, PERIOD_CURRENT, 0)){
      
      openTimeSell = iTime(_Symbol, PERIOD_CURRENT, 0);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl = bid + SL * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double tp = bid - TP * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, 1.0, bid, sl, tp, "Trade taken");
   }
}