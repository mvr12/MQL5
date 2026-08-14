//+------------------------------------------------------------------+
//| StrategyCombiner_EA_v2.mq5                                       |
//| Slim auto-trader: reads BUY/SELL from comb*.ex5 on the chart     |
//| All Combiner filters stay inside the indicator.                  |
//| New git version — does not replace EA v1.                        |
//+------------------------------------------------------------------+
#property strict
#property copyright "Strategy Combiner"
#property version   "2.00"
#property description "Trades buffers of comb082 (or any comb* Combiner) already on the chart."
#property tester_indicator "comb082"

#include <Trade/Trade.mqh>

enum ENUM_LOT_MODE
{
   LOT_FIXED = 0,
   LOT_RISK_PERCENT = 1
};

input group "=== Combiner on chart ==="
input string CombinerName   = "comb082"; // اسم فایل/شورت‌نیم: comb082
input string CombinerPrefix = "comb";    // اگر چند تا بود، اولی که با comb شروع شود

input group "=== Auto Trade ==="
input bool   AllowBuy              = true;
input bool   AllowSell             = true;
input bool   CloseAfterNBars       = true;
input int    ExitBars              = 2;      // مثل BarsForward اندیکاتور
input bool   CloseOpposite         = false;
input bool   OnePositionOnly       = true;
input bool   TradeOnlyNewBar       = true;
input bool   TradeClosedBarOnStart = true;
input int    MaxSpreadPoints       = 40;
input ulong  MagicNumber           = 20260814;
input int    SlippagePoints        = 20;
input string TradeComment          = "SC_EA_v2";
input bool   ShowPanel             = true;

input group "=== Money Management ==="
input ENUM_LOT_MODE LotMode          = LOT_FIXED;
input double        FixedLot         = 0.10;
input double        RiskPercent      = 1.0;
input int           StopLossPoints   = 0;
input int           TakeProfitPoints = 0;

#define SC_V2_BG   "SC_V2_BG"
#define SC_V2_LN   "SC_V2_LN_"

CTrade   trade;
int      g_handle = INVALID_HANDLE;
bool     g_ownHandle = false;
string   g_source = "";
string   g_lastAction = "init";
string   g_lastError = "";
datetime g_lastBar = 0;
datetime g_lastSignalBar = 0;
bool     g_startCheckDone = false;
datetime g_lastRetry = 0;

bool InTester()
{
   return (bool)(MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION));
}

void SetupFilling()
{
   const long mode = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((mode & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
      trade.SetTypeFilling(ORDER_FILLING_IOC);
   else if((mode & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
      trade.SetTypeFilling(ORDER_FILLING_FOK);
   else
      trade.SetTypeFilling(ORDER_FILLING_RETURN);
}

bool TradeAllowed(string &why)
{
   if(InTester())
   {
      why = "tester";
      return true;
   }
   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
   { why = "not connected"; return false; }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   { why = "AutoTrading OFF"; return false; }
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
   { why = "Allow Algo Trading OFF"; return false; }
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
   { why = "account trade OFF"; return false; }
   if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
   { why = "account experts OFF"; return false; }
   why = "OK";
   return true;
}

bool NameLooksLikeCombiner(const string name)
{
   if(name == "")
      return false;
   string low = name;
   StringToLower(low);
   string want = CombinerName;
   StringToLower(want);
   string pre = CombinerPrefix;
   StringToLower(pre);
   if(want != "" && StringFind(low, want) >= 0)
      return true;
   if(pre != "" && StringFind(low, pre) == 0)
      return true;
   return false;
}

int FindChartCombiner()
{
   const int windows = (int)ChartGetInteger(0, CHART_WINDOWS_TOTAL);
   for(int w = 0; w < windows; w++)
   {
      const int total = ChartIndicatorsTotal(0, w);
      for(int i = 0; i < total; i++)
      {
         const string name = ChartIndicatorName(0, w, i);
         if(!NameLooksLikeCombiner(name))
            continue;
         const int h = ChartIndicatorGet(0, w, name);
         if(h != INVALID_HANDLE)
         {
            g_source = "chart:" + name;
            g_ownHandle = false;
            Print("EA v2: chart Combiner ", name, " handle=", h);
            return h;
         }
      }
   }
   return INVALID_HANDLE;
}

// Literal "comb082" is required so Strategy Tester packs the indicator.
int LoadCombinerLiteral()
{
   ResetLastError();
   const int h = iCustom(_Symbol, _Period, "comb082");
   if(h != INVALID_HANDLE)
   {
      g_source = "iCustom:comb082";
      g_ownHandle = true;
      Print("EA v2: iCustom comb082 handle=", h);
      return h;
   }
   Print("EA v2: iCustom(\"comb082\") failed err=", GetLastError());
   return INVALID_HANDLE;
}

int LoadCombinerByInput()
{
   if(CombinerName == "" || CombinerName == "comb082")
      return INVALID_HANDLE;
   ResetLastError();
   const int h = iCustom(_Symbol, _Period, CombinerName);
   if(h != INVALID_HANDLE)
   {
      g_source = "iCustom:" + CombinerName;
      g_ownHandle = true;
      Print("EA v2: iCustom ", CombinerName, " handle=", h);
      return h;
   }
   Print("EA v2: iCustom(\"", CombinerName, "\") failed err=", GetLastError());
   return INVALID_HANDLE;
}

void ReleaseHandle()
{
   if(g_handle != INVALID_HANDLE && g_ownHandle)
      IndicatorRelease(g_handle);
   g_handle = INVALID_HANDLE;
   g_ownHandle = false;
   g_source = "";
}

bool EnsureHandle()
{
   if(g_handle != INVALID_HANDLE)
      return true;
   if(g_lastRetry != 0 && TimeCurrent() == g_lastRetry)
      return false;
   g_lastRetry = TimeCurrent();

   int h = INVALID_HANDLE;
   if(!InTester())
      h = FindChartCombiner();
   if(h == INVALID_HANDLE)
      h = LoadCombinerLiteral();
   if(h == INVALID_HANDLE)
      h = LoadCombinerByInput();

   if(h == INVALID_HANDLE)
   {
      g_lastError = "Combiner not found. Compile Indicators/comb082.mq5 and drop it on the chart (live) or keep name comb082 (tester).";
      return false;
   }

   g_handle = h;
   g_lastError = "";

   if(InTester() && MQLInfoInteger(MQL_VISUAL_MODE))
      ChartIndicatorAdd(0, 0, g_handle);

   return true;
}

bool IsSignalValue(const double v)
{
   if(v == EMPTY_VALUE || v == DBL_MAX)
      return false;
   if(!MathIsValidNumber(v))
      return false;
   if(v == 0.0)
      return false;
   return true;
}

int ReadClosedBarSignal(string &note)
{
   if(g_handle == INVALID_HANDLE)
   {
      note = "no handle";
      return 0;
   }
   const int calc = BarsCalculated(g_handle);
   if(calc < 5)
   {
      note = "calc=" + IntegerToString(calc);
      return 0;
   }
   double buy[], sell[];
   ArraySetAsSeries(buy, true);
   ArraySetAsSeries(sell, true);
   if(CopyBuffer(g_handle, 0, 0, 3, buy) < 2 || CopyBuffer(g_handle, 1, 0, 3, sell) < 2)
   {
      note = "CopyBuffer fail";
      return 0;
   }
   const bool b = IsSignalValue(buy[1]);
   const bool s = IsSignalValue(sell[1]);
   note = b ? "BUY buf" : (s ? "SELL buf" : "none");
   if(b && !s) return 1;
   if(s && !b) return -1;
   return 0;
}

string SignalText(const int s)
{
   if(s > 0) return "BUY";
   if(s < 0) return "SELL";
   return "NONE";
}

bool IsNewBar()
{
   datetime t = iTime(_Symbol, _Period, 0);
   if(t <= 0) return false;
   if(t == g_lastBar) return false;
   g_lastBar = t;
   return true;
}

int CountMyPositions(const int typeFilter = -1)
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(typeFilter >= 0 && (int)PositionGetInteger(POSITION_TYPE) != typeFilter) continue;
      n++;
   }
   return n;
}

void CloseMyPositions(const int typeFilter = -1)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(typeFilter >= 0 && (int)PositionGetInteger(POSITION_TYPE) != typeFilter) continue;
      trade.PositionClose(ticket);
   }
}

string BuildTradeComment(const datetime signalBar)
{
   return TradeComment + "|" + IntegerToString((long)signalBar);
}

datetime PositionSignalBarTime()
{
   string c = PositionGetString(POSITION_COMMENT);
   int p = StringFind(c, "|");
   if(p >= 0)
   {
      long t = StringToInteger(StringSubstr(c, p + 1));
      if(t > 0) return (datetime)t;
   }
   return (datetime)PositionGetInteger(POSITION_TIME);
}

bool PositionHasEncodedSignalBar()
{
   return (StringFind(PositionGetString(POSITION_COMMENT), "|") >= 0);
}

bool NBarsCompleted(const datetime mark, const bool encoded)
{
   int n = (ExitBars < 1) ? 1 : ExitBars;
   int sh = iBarShift(_Symbol, _Period, mark, false);
   if(sh < 0) return false;
   return encoded ? (sh >= n + 1) : (sh >= n);
}

void CloseExpiredNBarPositions()
{
   if(!CloseAfterNBars) return;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(!NBarsCompleted(PositionSignalBarTime(), PositionHasEncodedSignalBar()))
         continue;
      if(trade.PositionClose(ticket))
      {
         g_lastAction = "closed after N=" + IntegerToString(ExitBars);
         Print("EA v2: ", g_lastAction);
      }
      else
      {
         g_lastAction = "close fail " + trade.ResultRetcodeDescription();
         Print("EA v2: ", g_lastAction);
      }
   }
}

double NormalizeLot(double lot)
{
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0) step = 0.01;
   lot = MathFloor(lot / step + 1e-12) * step;
   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;
   int digits = 2;
   if(step < 0.01) digits = 3;
   if(step < 0.001) digits = 4;
   return NormalizeDouble(lot, digits);
}

double CalcLot(const double slPrice, const bool isBuy)
{
   if(LotMode == LOT_FIXED || StopLossPoints <= 0 || slPrice <= 0.0)
      return NormalizeLot(FixedLot);
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercent / 100.0;
   double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickVal <= 0.0 || tickSize <= 0.0) return NormalizeLot(FixedLot);
   double price = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double slDist = MathAbs(price - slPrice);
   if(slDist <= 0.0) return NormalizeLot(FixedLot);
   double lossPerLot = (slDist / tickSize) * tickVal;
   if(lossPerLot <= 0.0) return NormalizeLot(FixedLot);
   return NormalizeLot(riskMoney / lossPerLot);
}

bool SendOrder(const int signal, const double lot, const double sl, const double tp, const string comment)
{
   ENUM_ORDER_TYPE_FILLING fills[3];
   fills[0] = ORDER_FILLING_IOC;
   fills[1] = ORDER_FILLING_FOK;
   fills[2] = ORDER_FILLING_RETURN;
   for(int i = 0; i < 3; i++)
   {
      trade.SetTypeFilling(fills[i]);
      bool ok = (signal == 1)
                ? trade.Buy(lot, _Symbol, 0.0, sl, tp, comment)
                : trade.Sell(lot, _Symbol, 0.0, sl, tp, comment);
      if(ok) return true;
      if(trade.ResultRetcode() != TRADE_RETCODE_INVALID_FILL)
         break;
   }
   return false;
}

bool OpenTrade(const int signal, const datetime signalBar)
{
   if(signal == 1 && !AllowBuy) return false;
   if(signal == -1 && !AllowSell) return false;
   string why;
   if(!TradeAllowed(why))
   {
      g_lastAction = why;
      return false;
   }
   if(MaxSpreadPoints > 0 && SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > MaxSpreadPoints)
   {
      g_lastAction = "spread high";
      return false;
   }

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double sl = 0.0, tp = 0.0;
   if(signal == 1)
   {
      if(StopLossPoints > 0) sl = NormalizeDouble(ask - StopLossPoints * point, digits);
      if(TakeProfitPoints > 0) tp = NormalizeDouble(ask + TakeProfitPoints * point, digits);
   }
   else
   {
      if(StopLossPoints > 0) sl = NormalizeDouble(bid + StopLossPoints * point, digits);
      if(TakeProfitPoints > 0) tp = NormalizeDouble(bid - TakeProfitPoints * point, digits);
   }
   double lot = CalcLot(sl, signal == 1);
   if(lot <= 0.0) return false;
   if(!SendOrder(signal, lot, sl, tp, BuildTradeComment(signalBar)))
   {
      g_lastAction = "order " + IntegerToString((int)trade.ResultRetcode()) +
                     " " + trade.ResultRetcodeDescription();
      Print("EA v2: ", g_lastAction);
      return false;
   }
   g_lastAction = SignalText(signal) + " lot=" + DoubleToString(lot, 2) +
                  " N=" + IntegerToString(ExitBars);
   Print("EA v2: ", g_lastAction);
   return true;
}

void ProcessSignal(const int signal)
{
   if(signal == 0) return;
   datetime closedBar = iTime(_Symbol, _Period, 1);
   if(closedBar > 0 && closedBar == g_lastSignalBar) return;
   if(CloseOpposite)
   {
      if(signal == 1) CloseMyPositions(POSITION_TYPE_SELL);
      else CloseMyPositions(POSITION_TYPE_BUY);
   }
   if(OnePositionOnly && CountMyPositions() > 0)
   {
      g_lastAction = "skip: in position";
      return;
   }
   if(OpenTrade(signal, closedBar))
      g_lastSignalBar = closedBar;
}

void DeletePanel()
{
   ObjectDelete(0, SC_V2_BG);
   ObjectsDeleteAll(0, SC_V2_LN);
}

void DrawPanel(const string text)
{
   if(!ShowPanel)
   {
      DeletePanel();
      return;
   }
   string lines[];
   int n = StringSplit(text, '\n', lines);
   if(n < 1) n = 1;
   if(n > 14) n = 14;

   const int lineH = 12;
   const int width = 228;
   const int height = 10 + n * lineH + 8;

   if(ObjectFind(0, SC_V2_BG) < 0)
      ObjectCreate(0, SC_V2_BG, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, SC_V2_BG, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, SC_V2_BG, OBJPROP_XDISTANCE, 8);
   ObjectSetInteger(0, SC_V2_BG, OBJPROP_YDISTANCE, 52);
   ObjectSetInteger(0, SC_V2_BG, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, SC_V2_BG, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, SC_V2_BG, OBJPROP_BGCOLOR, C'12,18,28');
   ObjectSetInteger(0, SC_V2_BG, OBJPROP_COLOR, C'0,140,120');
   ObjectSetInteger(0, SC_V2_BG, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, SC_V2_BG, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, SC_V2_BG, OBJPROP_BACK, false);
   ObjectSetInteger(0, SC_V2_BG, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, SC_V2_BG, OBJPROP_HIDDEN, true);

   for(int i = 0; i < n; i++)
   {
      const string nm = SC_V2_LN + IntegerToString(i);
      if(ObjectFind(0, nm) < 0)
         ObjectCreate(0, nm, OBJ_LABEL, 0, 0, 0);
      color clr = C'170,220,205';
      if(i == 0) clr = C'255,210,80';
      if(StringFind(lines[i], "ERR") >= 0 || StringFind(lines[i], "fail") >= 0)
         clr = C'255,100,80';
      ObjectSetInteger(0, nm, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, nm, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
      ObjectSetInteger(0, nm, OBJPROP_XDISTANCE, 16);
      ObjectSetInteger(0, nm, OBJPROP_YDISTANCE, 56 + i * lineH);
      ObjectSetString(0, nm, OBJPROP_TEXT, lines[i]);
      ObjectSetString(0, nm, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, nm, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, nm, OBJPROP_BACK, false);
   }
   for(int i = n; i < 14; i++)
      ObjectDelete(0, SC_V2_LN + IntegerToString(i));
}

void RunEA(const bool tradingNow)
{
   EnsureHandle();
   string note = "";
   const int signal = ReadClosedBarSignal(note);
   if(tradingNow)
   {
      CloseExpiredNBarPositions();
      ProcessSignal(signal);
   }

   string why;
   TradeAllowed(why);
   string text =
      "SC EA v2  " + _Symbol + "\n" +
      (g_source == "" ? "src: --" : g_source) + "\n" +
      "sig " + SignalText(signal) + "  " + note + "\n" +
      "exit N=" + IntegerToString(ExitBars) +
      "  pos=" + IntegerToString(CountMyPositions()) + "\n" +
      "algo " + why + "\n" +
      g_lastAction;
   if(g_lastError != "")
      text += "\nERR " + g_lastError;
   DrawPanel(text);
}

int OnInit()
{
   if(ExitBars < 1)
   {
      Print("EA v2 ERROR: ExitBars must be >= 1");
      return INIT_FAILED;
   }

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(SlippagePoints);
   SetupFilling();

   g_startCheckDone = false;
   g_lastBar = 0;
   g_lastRetry = 0;
   g_lastAction = "started";

   EnsureHandle();
   if(g_handle == INVALID_HANDLE)
      Print("EA v2: Combiner not ready yet — ", g_lastError);

   EventSetTimer(1);
   RunEA(false);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   DeletePanel();
   ReleaseHandle();
}

void OnTimer()
{
   bool nb = IsNewBar();
   bool go = false;
   if(TradeClosedBarOnStart && !g_startCheckDone)
   {
      go = true;
      g_startCheckDone = true;
   }
   else if(!TradeOnlyNewBar || nb)
      go = true;
   RunEA(go);
}

void OnTick()
{
   bool nb = IsNewBar();
   bool go = false;
   if(TradeClosedBarOnStart && !g_startCheckDone)
   {
      go = true;
      g_startCheckDone = true;
   }
   else if(!TradeOnlyNewBar || nb)
      go = true;
   RunEA(go);
}
//+------------------------------------------------------------------+
