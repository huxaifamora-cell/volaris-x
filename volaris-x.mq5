//+------------------------------------------------------------------+
//|                                      VOLARIS_X_MONITOR.mq5      |
//|                              Real-time WebSocket Communication   |
//+------------------------------------------------------------------+
#property copyright "VOLARIS X MONITOR"
#property version   "1.00"
#property strict

//--- Input Parameters
input group "=== WEBSOCKET SETTINGS ==="
input string InpWebSocketUrl = "wss://your-volarix-server.onrender.com"; // WebSocket Server URL
input bool InpInstantRemoval = true;
input int InpHeartbeatInterval = 30;
input int InpReconnectAttempts = 3;

input group "=== SIGNAL LOGIC SETTINGS ==="
input int InpBBPeriod = 20;
input double InpBBDeviation = 2.0;
input int InpSMAPeriod = 10;
input int InpEMAPeriod = 10;
input int InpSlopeBars = 5;
input double InpMinSlopeThreshold = 0.0;

input group "=== INDICATOR COLORS ==="
input color InpBBColor = clrCyan;
input color InpSMAColor = clrMagenta;
input color InpEMAColor = clrBlue;
input int InpBBWidth = 1;
input int InpSMAWidth = 2;
input int InpEMAWidth = 2;

input group "=== VOLATILITY INDICES ==="
input bool InpMonitorVol10      = true;
input bool InpMonitorVol15      = true;
input bool InpMonitorVol25      = true;
input bool InpMonitorVol30      = true;
input bool InpMonitorVol50      = true;
input bool InpMonitorVol75      = true;
input bool InpMonitorVol90      = true;
input bool InpMonitorVol100     = true;
input bool InpMonitorVol150     = true;
input bool InpMonitorVol250     = true;
input bool InpMonitorVol5_1s    = true;
input bool InpMonitorVol10_1s   = true;
input bool InpMonitorVol15_1s   = true;
input bool InpMonitorVol25_1s   = true;
input bool InpMonitorVol30_1s   = true;
input bool InpMonitorVol50_1s   = true;
input bool InpMonitorVol75_1s   = true;
input bool InpMonitorVol90_1s   = true;
input bool InpMonitorVol100_1s  = true;
input bool InpMonitorVol150_1s  = true;
input bool InpMonitorVol250_1s  = true;
input bool InpMonitorHFVol10    = true;
input bool InpMonitorHFVol25    = true;
input bool InpMonitorHFVol50    = true;
input bool InpMonitorHFVol75    = true;
input bool InpMonitorHFVol100   = true;

input group "=== DEBUG SETTINGS ==="
input bool InpEnableDebugLog = false;

//--- Global Variables
struct ActiveSignal
{
   string symbol;
   string timeframe;
   string tradeType;
   string h4Trend;
   string d1Trend;
   double minLot;
   double minMargin;
   int priority;
   datetime timestamp;
   bool active;
};

struct SymbolData
{
   string name;
   string displayName;
   bool enabled;
   bool wasValidM30;
   bool wasValidH1;
   bool isValidM30;
   bool isValidH1;
   int hBB_M30;
   int hSMA_M30;
   int hEMA_M30;
   int hBB_H1;
   int hSMA_H1;
   int hEMA_H1;
};

SymbolData symbols[];
ActiveSignal activeSignals[];
int totalSymbols = 26;
int handleBB, handleSMA, handleEMA;

datetime lastHeartbeat = 0;
datetime lastSuccessfulRequest = 0;
bool isConnected = false;
int consecutiveFailures = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   ArrayResize(symbols, totalSymbols);
   ArrayResize(activeSignals, 0);

   // Standard Volatility Indices
   symbols[0].name  = "Volatility 10 Index";   symbols[0].displayName  = "VOL10";    symbols[0].enabled = InpMonitorVol10;
   symbols[1].name  = "Volatility 15 Index";   symbols[1].displayName  = "VOL15";    symbols[1].enabled = InpMonitorVol15;
   symbols[2].name  = "Volatility 25 Index";   symbols[2].displayName  = "VOL25";    symbols[2].enabled = InpMonitorVol25;
   symbols[3].name  = "Volatility 30 Index";   symbols[3].displayName  = "VOL30";    symbols[3].enabled = InpMonitorVol30;
   symbols[4].name  = "Volatility 50 Index";   symbols[4].displayName  = "VOL50";    symbols[4].enabled = InpMonitorVol50;
   symbols[5].name  = "Volatility 75 Index";   symbols[5].displayName  = "VOL75";    symbols[5].enabled = InpMonitorVol75;
   symbols[6].name  = "Volatility 90 Index";   symbols[6].displayName  = "VOL90";    symbols[6].enabled = InpMonitorVol90;
   symbols[7].name  = "Volatility 100 Index";  symbols[7].displayName  = "VOL100";   symbols[7].enabled = InpMonitorVol100;
   symbols[8].name  = "Volatility 150 Index";  symbols[8].displayName  = "VOL150";   symbols[8].enabled = InpMonitorVol150;
   symbols[9].name  = "Volatility 250 Index";  symbols[9].displayName  = "VOL250";   symbols[9].enabled = InpMonitorVol250;

   // 1s Volatility Indices
   symbols[10].name = "Volatility 5 (1s) Index";   symbols[10].displayName = "VOL5(1s)";   symbols[10].enabled = InpMonitorVol5_1s;
   symbols[11].name = "Volatility 10 (1s) Index";  symbols[11].displayName = "VOL10(1s)";  symbols[11].enabled = InpMonitorVol10_1s;
   symbols[12].name = "Volatility 15 (1s) Index";  symbols[12].displayName = "VOL15(1s)";  symbols[12].enabled = InpMonitorVol15_1s;
   symbols[13].name = "Volatility 25 (1s) Index";  symbols[13].displayName = "VOL25(1s)";  symbols[13].enabled = InpMonitorVol25_1s;
   symbols[14].name = "Volatility 30 (1s) Index";  symbols[14].displayName = "VOL30(1s)";  symbols[14].enabled = InpMonitorVol30_1s;
   symbols[15].name = "Volatility 50 (1s) Index";  symbols[15].displayName = "VOL50(1s)";  symbols[15].enabled = InpMonitorVol50_1s;
   symbols[16].name = "Volatility 75 (1s) Index";  symbols[16].displayName = "VOL75(1s)";  symbols[16].enabled = InpMonitorVol75_1s;
   symbols[17].name = "Volatility 90 (1s) Index";  symbols[17].displayName = "VOL90(1s)";  symbols[17].enabled = InpMonitorVol90_1s;
   symbols[18].name = "Volatility 100 (1s) Index"; symbols[18].displayName = "VOL100(1s)"; symbols[18].enabled = InpMonitorVol100_1s;
   symbols[19].name = "Volatility 150 (1s) Index"; symbols[19].displayName = "VOL150(1s)"; symbols[19].enabled = InpMonitorVol150_1s;
   symbols[20].name = "Volatility 250 (1s) Index"; symbols[20].displayName = "VOL250(1s)"; symbols[20].enabled = InpMonitorVol250_1s;

   // High Frequency Volatility Indices
   symbols[21].name = "High Frequency Volatility 10 Index";  symbols[21].displayName = "HFV10";  symbols[21].enabled = InpMonitorHFVol10;
   symbols[22].name = "High Frequency Volatility 25 Index";  symbols[22].displayName = "HFV25";  symbols[22].enabled = InpMonitorHFVol25;
   symbols[23].name = "High Frequency Volatility 50 Index";  symbols[23].displayName = "HFV50";  symbols[23].enabled = InpMonitorHFVol50;
   symbols[24].name = "High Frequency Volatility 75 Index";  symbols[24].displayName = "HFV75";  symbols[24].enabled = InpMonitorHFVol75;
   symbols[25].name = "High Frequency Volatility 100 Index"; symbols[25].displayName = "HFV100"; symbols[25].enabled = InpMonitorHFVol100;

   Print("🔧 Creating indicator handles for all symbols...");
   int successCount = 0;

   for(int i = 0; i < totalSymbols; i++)
   {
      symbols[i].wasValidM30 = false;
      symbols[i].wasValidH1  = false;
      symbols[i].isValidM30  = false;
      symbols[i].isValidH1   = false;

      if(!symbols[i].enabled)
      {
         symbols[i].hBB_M30  = INVALID_HANDLE;
         symbols[i].hSMA_M30 = INVALID_HANDLE;
         symbols[i].hEMA_M30 = INVALID_HANDLE;
         symbols[i].hBB_H1   = INVALID_HANDLE;
         symbols[i].hSMA_H1  = INVALID_HANDLE;
         symbols[i].hEMA_H1  = INVALID_HANDLE;
         continue;
      }

      if(!SymbolSelect(symbols[i].name, true))
      {
         Print("⚠️ Failed to select symbol: ", symbols[i].name);
         symbols[i].enabled = false;
         continue;
      }

      symbols[i].hBB_M30  = iBands(symbols[i].name, PERIOD_M30, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
      symbols[i].hSMA_M30 = iMA(symbols[i].name, PERIOD_M30, InpSMAPeriod, 0, MODE_SMA, PRICE_CLOSE);
      symbols[i].hEMA_M30 = iMA(symbols[i].name, PERIOD_M30, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
      symbols[i].hBB_H1   = iBands(symbols[i].name, PERIOD_H1, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
      symbols[i].hSMA_H1  = iMA(symbols[i].name, PERIOD_H1, InpSMAPeriod, 0, MODE_SMA, PRICE_CLOSE);
      symbols[i].hEMA_H1  = iMA(symbols[i].name, PERIOD_H1, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);

      if(symbols[i].hBB_M30 == INVALID_HANDLE || symbols[i].hSMA_M30 == INVALID_HANDLE ||
         symbols[i].hEMA_M30 == INVALID_HANDLE || symbols[i].hBB_H1 == INVALID_HANDLE  ||
         symbols[i].hSMA_H1 == INVALID_HANDLE  || symbols[i].hEMA_H1 == INVALID_HANDLE)
      {
         Print("❌ Failed to create indicators for ", symbols[i].name);
         symbols[i].enabled = false;
         continue;
      }

      successCount++;
      Print("✅ ", symbols[i].name, " - handles created");
   }

   Print("✅ Successfully created handles for ", successCount, " symbols");

   handleBB  = iBands(_Symbol, PERIOD_CURRENT, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
   handleSMA = iMA(_Symbol, PERIOD_CURRENT, InpSMAPeriod, 0, MODE_SMA, PRICE_CLOSE);
   handleEMA = iMA(_Symbol, PERIOD_CURRENT, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);

   if(handleBB == INVALID_HANDLE || handleSMA == INVALID_HANDLE || handleEMA == INVALID_HANDLE)
   {
      Print("❌ Error creating chart indicators!");
      return(INIT_FAILED);
   }

   ChartIndicatorAdd(0, 0, handleBB);
   ChartIndicatorAdd(0, 0, handleSMA);
   ChartIndicatorAdd(0, 0, handleEMA);

   Print("╔════════════════════════════════════════╗");
   Print("║  Volaris X Monitor                     ║");
   Print("╚════════════════════════════════════════╝");
   Print("📡 WebSocket: ", InpWebSocketUrl);
   Print("💓 Heartbeat: Every ", InpHeartbeatInterval, " seconds");
   Print("📊 Active symbols: ", successCount, " volatility indices");

   if(SendHeartbeat())
   {
      Print("✅ Connected to server!");
      isConnected = true;
   }
   else
   {
      Print("⚠️ Initial connection failed - will retry");
      isConnected = false;
   }

   Sleep(3000);

   Print("🔍 Performing initial signal scan...");
   for(int i = 0; i < totalSymbols; i++)
   {
      if(!symbols[i].enabled) continue;
      CheckAndUpdateSignal(i, false);
      CheckAndUpdateSignal(i, true);
   }
   Print("✅ Initial scan complete!");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   for(int i = 0; i < totalSymbols; i++)
   {
      if(symbols[i].hBB_M30  != INVALID_HANDLE) IndicatorRelease(symbols[i].hBB_M30);
      if(symbols[i].hSMA_M30 != INVALID_HANDLE) IndicatorRelease(symbols[i].hSMA_M30);
      if(symbols[i].hEMA_M30 != INVALID_HANDLE) IndicatorRelease(symbols[i].hEMA_M30);
      if(symbols[i].hBB_H1   != INVALID_HANDLE) IndicatorRelease(symbols[i].hBB_H1);
      if(symbols[i].hSMA_H1  != INVALID_HANDLE) IndicatorRelease(symbols[i].hSMA_H1);
      if(symbols[i].hEMA_H1  != INVALID_HANDLE) IndicatorRelease(symbols[i].hEMA_H1);
   }

   if(handleBB  != INVALID_HANDLE) IndicatorRelease(handleBB);
   if(handleSMA != INVALID_HANDLE) IndicatorRelease(handleSMA);
   if(handleEMA != INVALID_HANDLE) IndicatorRelease(handleEMA);

   Print("Volaris X Monitor stopped - all handles released");
}

//+------------------------------------------------------------------+
void OnTick()
{
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, PERIOD_M1, 0);
   bool newBar = (currentBarTime != lastBarTime);
   if(newBar) lastBarTime = currentBarTime;

   CheckConnectionHealth();

   for(int i = 0; i < totalSymbols; i++)
   {
      if(!symbols[i].enabled) continue;
      CheckAndUpdateSignal(i, false);
      CheckAndUpdateSignal(i, true);
   }
}

//+------------------------------------------------------------------+
void CheckConnectionHealth()
{
   datetime currentTime = TimeCurrent();
   if(currentTime - lastHeartbeat >= InpHeartbeatInterval)
   {
      bool success = SendHeartbeat();
      if(success)
      {
         if(!isConnected)
         {
            Print("✅ Reconnected to server!");
            isConnected = true;
            consecutiveFailures = 0;
            ResyncAllSignals();
         }
      }
      else
      {
         consecutiveFailures++;
         if(consecutiveFailures >= InpReconnectAttempts && isConnected)
         {
            Print("❌ Connection lost after ", consecutiveFailures, " failures");
            isConnected = false;
         }
      }
      lastHeartbeat = currentTime;
   }
}

//+------------------------------------------------------------------+
bool SendHeartbeat()
{
   string json = "{\"type\":\"heartbeat\",\"timestamp\":" + IntegerToString((int)TimeCurrent()) +
                 ",\"active_signals\":" + IntegerToString(ArraySize(activeSignals)) + "}";
   return SendToWebSocket(json);
}

//+------------------------------------------------------------------+
void ResyncAllSignals()
{
   for(int i = 0; i < ArraySize(activeSignals); i++)
   {
      if(!activeSignals[i].active) continue;
      string json = "{\"type\":\"signal\"," +
                    "\"symbol\":\"" + activeSignals[i].symbol + "\"," +
                    "\"timeframe\":\"" + activeSignals[i].timeframe + "\"," +
                    "\"trade_type\":\"" + activeSignals[i].tradeType + "\"," +
                    "\"priority\":" + IntegerToString(activeSignals[i].priority) + "," +
                    "\"timestamp\":" + IntegerToString((int)activeSignals[i].timestamp) + "}";
      SendToWebSocket(json);
      Sleep(100);
   }
}

//+------------------------------------------------------------------+
double CalculateBBSlope(double &bbMiddle[], int bars)
{
   if(bars < 2) return 0;
   double totalChange = 0;
   int validChanges = 0;
   for(int i = 0; i < bars - 1; i++)
   {
      if(bbMiddle[i] != EMPTY_VALUE && bbMiddle[i + 1] != EMPTY_VALUE &&
         bbMiddle[i] != 0 && bbMiddle[i + 1] != 0)
      {
         totalChange += bbMiddle[i] - bbMiddle[i + 1];
         validChanges++;
      }
   }
   return validChanges == 0 ? 0 : totalChange / validChanges;
}

//+------------------------------------------------------------------+
void CheckAndUpdateSignal(int symbolIndex, bool isH1)
{
   if(!symbols[symbolIndex].enabled) return;

   string symbolName = symbols[symbolIndex].name;
   string displayName = symbols[symbolIndex].displayName;
   ENUM_TIMEFRAMES timeframe = isH1 ? PERIOD_H1 : PERIOD_M30;

   int hBB  = isH1 ? symbols[symbolIndex].hBB_H1  : symbols[symbolIndex].hBB_M30;
   int hSMA = isH1 ? symbols[symbolIndex].hSMA_H1 : symbols[symbolIndex].hSMA_M30;
   int hEMA = isH1 ? symbols[symbolIndex].hEMA_H1 : symbols[symbolIndex].hEMA_M30;

   if(hBB == INVALID_HANDLE || hSMA == INVALID_HANDLE || hEMA == INVALID_HANDLE) return;

   int barsNeeded = MathMax(InpSlopeBars + 2, 5);
   if(Bars(symbolName, timeframe) < barsNeeded) return;
   if(BarsCalculated(hBB) < barsNeeded || BarsCalculated(hSMA) < barsNeeded || BarsCalculated(hEMA) < barsNeeded) return;

   double bbMiddle[], smaValues[], emaValues[];
   ArraySetAsSeries(bbMiddle,  true);
   ArraySetAsSeries(smaValues, true);
   ArraySetAsSeries(emaValues, true);

   if(CopyBuffer(hBB,  0, 0, barsNeeded, bbMiddle)  != barsNeeded) return;
   if(CopyBuffer(hSMA, 0, 0, barsNeeded, smaValues) != barsNeeded) return;
   if(CopyBuffer(hEMA, 0, 0, barsNeeded, emaValues) != barsNeeded) return;

   bool dataValid = true;
   for(int i = 0; i < MathMin(3, barsNeeded); i++)
   {
      if(bbMiddle[i] == EMPTY_VALUE || bbMiddle[i] == 0 ||
         smaValues[i] == EMPTY_VALUE || smaValues[i] == 0 ||
         emaValues[i] == EMPTY_VALUE || emaValues[i] == 0)
      { dataValid = false; break; }
   }
   if(!dataValid) return;

   double bbSlope  = CalculateBBSlope(bbMiddle, InpSlopeBars);
   double absSlope = MathAbs(bbSlope);

   // Volatility indices: BUY when slope up + EMA above BB+SMA, SELL when slope down + EMA below BB+SMA
   bool condBuy  = (bbSlope > 0) && (absSlope >= InpMinSlopeThreshold) && (emaValues[0] > bbMiddle[0]) && (emaValues[0] > smaValues[0]);
   bool condSell = (bbSlope < 0) && (absSlope >= InpMinSlopeThreshold) && (emaValues[0] < bbMiddle[0]) && (emaValues[0] < smaValues[0]);

   bool conditionsMet = condBuy || condSell;
   string tradeType   = condBuy ? "BUY" : "SELL";

   bool wasValid = isH1 ? symbols[symbolIndex].wasValidH1 : symbols[symbolIndex].wasValidM30;

   if(conditionsMet && !wasValid)
   {
      double minLot    = SymbolInfoDouble(symbolName, SYMBOL_VOLUME_MIN);
      double minMargin = CalculateMargin(symbolName, minLot);
      AddActiveSignal(displayName, timeframe, tradeType, minLot, minMargin);
      SendSignalToWebSocket(displayName, timeframe, tradeType, minLot, minMargin);

      string tf = EnumToString(timeframe);
      StringReplace(tf, "PERIOD_", "");
      Print("✅ NEW SIGNAL: ", symbolName, " ", tf, " ", tradeType);
   }
   else if(!conditionsMet && wasValid && InpInstantRemoval)
   {
      string tf = EnumToString(timeframe);
      StringReplace(tf, "PERIOD_", "");
      RemoveActiveSignal(displayName, timeframe);
      RemoveSignalFromWebSocket(displayName, timeframe);
      Print("❌ REMOVED: ", symbolName, " ", tf);
   }

   if(isH1)
   {
      symbols[symbolIndex].isValidH1  = conditionsMet;
      symbols[symbolIndex].wasValidH1 = conditionsMet;
   }
   else
   {
      symbols[symbolIndex].isValidM30  = conditionsMet;
      symbols[symbolIndex].wasValidM30 = conditionsMet;
   }
}

//+------------------------------------------------------------------+
void AddActiveSignal(string displayName, ENUM_TIMEFRAMES timeframe, string tradeType, double minLot, double minMargin)
{
   string tf = EnumToString(timeframe);
   StringReplace(tf, "PERIOD_", "");

   for(int i = 0; i < ArraySize(activeSignals); i++)
   {
      if(activeSignals[i].symbol == displayName && activeSignals[i].timeframe == tf)
      {
         activeSignals[i].tradeType  = tradeType;
         activeSignals[i].minLot     = minLot;
         activeSignals[i].minMargin  = minMargin;
         activeSignals[i].timestamp  = TimeCurrent();
         activeSignals[i].active     = true;
         return;
      }
   }

   int newSize = ArraySize(activeSignals) + 1;
   ArrayResize(activeSignals, newSize);
   activeSignals[newSize-1].symbol    = displayName;
   activeSignals[newSize-1].timeframe = tf;
   activeSignals[newSize-1].tradeType = tradeType;
   activeSignals[newSize-1].minLot    = minLot;
   activeSignals[newSize-1].minMargin = minMargin;
   activeSignals[newSize-1].priority  = (timeframe == PERIOD_H1) ? 2 : 1;
   activeSignals[newSize-1].timestamp = TimeCurrent();
   activeSignals[newSize-1].active    = true;
}

//+------------------------------------------------------------------+
void RemoveActiveSignal(string displayName, ENUM_TIMEFRAMES timeframe)
{
   string tf = EnumToString(timeframe);
   StringReplace(tf, "PERIOD_", "");
   for(int i = 0; i < ArraySize(activeSignals); i++)
   {
      if(activeSignals[i].symbol == displayName && activeSignals[i].timeframe == tf)
      {
         activeSignals[i].active = false;
         return;
      }
   }
}

//+------------------------------------------------------------------+
void SendSignalToWebSocket(string displayName, ENUM_TIMEFRAMES timeframe, string tradeType, double minLot, double minMargin)
{
   string tf       = EnumToString(timeframe);
   StringReplace(tf, "PERIOD_", "");
   int priority    = (timeframe == PERIOD_H1) ? 2 : 1;
   datetime ts     = TimeCurrent();

   string json = "{\"type\":\"signal\"," +
                 "\"symbol\":\"" + displayName + "\"," +
                 "\"timeframe\":\"" + tf + "\"," +
                 "\"trade_type\":\"" + tradeType + "\"," +
                 "\"min_lot\":" + DoubleToString(minLot, 2) + "," +
                 "\"min_margin\":" + DoubleToString(minMargin, 2) + "," +
                 "\"priority\":" + IntegerToString(priority) + "," +
                 "\"timestamp\":" + IntegerToString((int)ts) + "}";
   SendToWebSocket(json);
}

//+------------------------------------------------------------------+
void RemoveSignalFromWebSocket(string displayName, ENUM_TIMEFRAMES timeframe)
{
   string tf = EnumToString(timeframe);
   StringReplace(tf, "PERIOD_", "");
   string json = "{\"type\":\"remove_signal\"," +
                 "\"symbol\":\"" + displayName + "\"," +
                 "\"timeframe\":\"" + tf + "\"}";
   SendToWebSocket(json);
}

//+------------------------------------------------------------------+
bool SendToWebSocket(string json)
{
   string url = InpWebSocketUrl;
   StringReplace(url, "ws://",  "http://");
   StringReplace(url, "wss://", "https://");

   char post[], result[];
   int len = StringToCharArray(json, post, 0, WHOLE_ARRAY, CP_UTF8);
   if(len > 0) ArrayResize(post, len - 1);

   string headers = "Content-Type: application/json\r\n";
   ResetLastError();
   int res = WebRequest("POST", url, headers, 5000, post, result, headers);

   if(res == -1)
   {
      int error = GetLastError();
      if(error == 4060) Print("⚠️ WebRequest NOT enabled! Add to whitelist: ", url);
      else if(InpEnableDebugLog) Print("❌ WebRequest ERROR: ", error);
      return false;
   }
   else if(res == 200)
   {
      lastSuccessfulRequest = TimeCurrent();
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
double CalculateMargin(string symbolName, double lotSize)
{
   double margin = 0;
   double price  = SymbolInfoDouble(symbolName, SYMBOL_ASK);
   if(price == 0) return 0;
   if(!OrderCalcMargin(ORDER_TYPE_BUY, symbolName, lotSize, price, margin))
   {
      double contractSize = SymbolInfoDouble(symbolName, SYMBOL_TRADE_CONTRACT_SIZE);
      long leverage = AccountInfoInteger(ACCOUNT_LEVERAGE);
      if(leverage == 0) leverage = 1;
      margin = (contractSize * lotSize * price) / leverage;
   }
   return margin;
}
//+------------------------------------------------------------------+
