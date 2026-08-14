//+------------------------------------------------------------------+
//| StrategyCombiner_EA_v1.mq5                                       |
//| Auto-trader driven by StrategyCombiner_v1 buffers                |
//| Exit = same as indicator: close after BarsForward candles        |
//| Does not modify the indicator file.                              |
//+------------------------------------------------------------------+
#property strict
#property copyright "Strategy Combiner"
#property version   "1.20"
#property description "Auto trader for StrategyCombiner_v1. Put Combiner on the chart or compile it first."
#property tester_indicator "StrategyCombiner_v1"

#include <Trade/Trade.mqh>

//==================================================================
//  ENUMS — must match StrategyCombiner_v1.mq5
//==================================================================
enum ENUM_TREND_COMPARE
{
   TREND_CMP_CLOSE  = 0,
   TREND_CMP_OPEN   = 1,
   TREND_CMP_HIGH   = 2,
   TREND_CMP_LOW    = 3,
   TREND_CMP_SIGNAL = 4
};

enum ENUM_TREND_SIDE
{
   TREND_BUY_ABOVE_SELL_BELOW = 0,
   TREND_BUY_BELOW_SELL_ABOVE = 1
};

enum ENUM_TREND_SOURCE
{
   TREND_SOURCE_MA     = 0,
   TREND_SOURCE_CUSTOM = 1
};

enum ENUM_SLOT_MODE
{
   SLOT_MODE_BUFFERS      = 0,
   SLOT_MODE_CROSS_SIGNAL = 1,
   SLOT_MODE_CROSS_TREND  = 2
};

enum ENUM_TREND_CROSS_ROLE
{
   TREND_CROSS_SIGNAL    = 0,
   TREND_CROSS_NEW_TREND = 1
};

enum ENUM_PROFIT_UNIT
{
   UNIT_PIPS   = 0,
   UNIT_POINTS = 1
};

enum ENUM_LOT_MODE
{
   LOT_FIXED = 0,
   LOT_RISK_PERCENT = 1
};

enum ENUM_COMBINER_SOURCE
{
   COMBINER_CHART_THEN_FILE = 0, // اول اندیکاتور روی همین چارت، بعد فایل
   COMBINER_CHART_ONLY      = 1,
   COMBINER_FILE_ONLY       = 2
};


//==================================================================
//  SAME SETTINGS AS THE INDICATOR
//==================================================================
input group "=== Custom Indicator 1 ==="
input bool           UseIndicator1         = true;
input ENUM_SLOT_MODE Indicator1_Mode       = SLOT_MODE_BUFFERS;
input string         Indicator1_Name       = "Market\\Dark Bands MT5";
input int            Indicator1_BuyBuffer  = 0;
input int            Indicator1_SellBuffer = 1;

input group "=== Custom Indicator 2 ==="
input bool           UseIndicator2         = false; // پیش‌فرض خاموش تا بدون فایل دوم EA حذف نشود
input ENUM_SLOT_MODE Indicator2_Mode       = SLOT_MODE_BUFFERS;
input string         Indicator2_Name       = "MySecondIndicator";
input int            Indicator2_BuyBuffer  = 0;
input int            Indicator2_SellBuffer = 1;

input group "=== Trend Confirmation ==="
input bool               UseTrendIndicator     = true;
input bool               UseTrendLineFilter    = true;
input ENUM_TREND_SOURCE  TrendSource           = TREND_SOURCE_MA;
input int                TrendMA_Period        = 50;
input ENUM_MA_METHOD     TrendMA_Method        = MODE_EMA;
input ENUM_APPLIED_PRICE TrendMA_AppliedPrice  = PRICE_CLOSE;
input string             TrendIndicator_Name   = "Examples\\Custom Moving Average";
input int                TrendIndicator_Buffer = 0;
input ENUM_TREND_COMPARE TrendCompareWith      = TREND_CMP_CLOSE;
input ENUM_TREND_SIDE    TrendSideRule         = TREND_BUY_ABOVE_SELL_BELOW;

input group "=== Trend Angle (degrees) ==="
input bool   UseTrendAngleFilter = false;
input int    TrendAnglePeriod    = 5;
input double AngleBuyFrom        = 25.0;
input double AngleBuyTo          = 75.0;
input double AngleSellFrom       = -90.0;
input double AngleSellTo         = -38.0;

input group "=== Cross of two trend lines ==="
input bool                  UseTrendLineCross = false;
input ENUM_TREND_CROSS_ROLE TrendCrossRole    = TREND_CROSS_SIGNAL;
input int                   TrendLine1_Buffer = 0;
input int                   TrendLine2_Buffer = 0;

input group "=== Count & Outcome ==="
input int    StatsLookbackBars = 1000;
input int    BarsForward       = 2;     // N کندل بعد — معامله همین‌جا بسته می‌شود
input bool   IgnoreZeroValues  = true;

input group "=== Trading Days ==="
input bool   UseDayFilter     = true;
input bool   Monday           = true;
input bool   Tuesday          = true;
input bool   Wednesday        = true;
input bool   Thursday         = true;
input bool   Friday           = true;
input bool   Saturday         = false;
input bool   Sunday           = false;

input group "=== Trading Hours ==="
input bool   UseTimeFilter    = true;
input int    StartHour        = 0;
input int    StartMinute      = 0;
input int    EndHour          = 23;
input int    EndMinute        = 59;


//==================================================================
//  EA TRADE SETTINGS
//==================================================================
input group "=== Auto Trade ==="
input bool         AllowBuy           = true;
input bool         AllowSell          = true;
input bool         CloseAfterNBars    = true;
input bool         CloseOpposite      = false;
input bool         OnePositionOnly    = true;
input bool         TradeOnlyNewBar    = true;
input bool         TradeClosedBarOnStart = true; // همان لحظه نصب، سیگنال کندل بسته را بگیر
input int          MaxSpreadPoints    = 40;
input ulong        MagicNumber        = 20260814;
input int          SlippagePoints     = 20;
input string       TradeComment       = "SC_EA_v1";
input bool         ShowStatusPanel    = true;

input group "=== Money Management ==="
input ENUM_LOT_MODE LotMode           = LOT_FIXED;
input double        FixedLot          = 0.10;
input double        RiskPercent       = 1.0;
input int           StopLossPoints    = 0;
input int           TakeProfitPoints  = 0;

input group "=== Combiner File ==="
input ENUM_COMBINER_SOURCE CombinerSource    = COMBINER_CHART_THEN_FILE;
input string               CombinerName      = "StrategyCombiner_v1";
input string               CombinerShortName = "Strategy Combiner";


#define SC_EA_STATUS_NAME "SC_EA_STATUS"

CTrade   trade;
int      g_handle = INVALID_HANDLE;
bool     g_handleFromChart = false;
string   g_handleSource = "";
string   g_lastError = "";
string   g_lastAction = "init";
datetime g_lastBar = 0;
datetime g_lastSignalBar = 0;
datetime g_lastRetry = 0;
bool     g_startCheckDone = false;


bool IsSignalValue(const double v)
{
   if(v == EMPTY_VALUE || v == DBL_MAX)
      return false;
   if(!MathIsValidNumber(v))
      return false;
   if(IgnoreZeroValues && v == 0.0)
      return false;
   return true;
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
   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
   {
      why = "terminal not connected";
      return false;
   }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      why = "AutoTrading is OFF (toolbar button)";
      return false;
   }
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      why = "EA live trading checkbox is OFF";
      return false;
   }
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
   {
      why = "account trading disabled";
      return false;
   }
   if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
   {
      why = "account experts disabled";
      return false;
   }
   const long smode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   if(smode == SYMBOL_TRADE_MODE_DISABLED)
   {
      why = "symbol trade disabled";
      return false;
   }
   why = "OK";
   return true;
}

int FindChartCombiner()
{
   const int total = ChartIndicatorsTotal(0, 0);
   for(int i = 0; i < total; i++)
   {
      const string name = ChartIndicatorName(0, 0, i);
      if(name == "")
         continue;
      if(StringFind(name, CombinerShortName) < 0 &&
         StringFind(name, "StrategyCombiner") < 0 &&
         StringFind(name, CombinerName) < 0)
         continue;

      const int h = ChartIndicatorGet(0, 0, name);
      if(h != INVALID_HANDLE)
      {
         g_handleSource = "chart:" + name;
         Print("EA: using Combiner already on chart: ", name, " handle=", h);
         return h;
      }
   }
   return INVALID_HANDLE;
}

int LoadCombinerFile(const string name)
{
   ResetLastError();
   const int h = iCustom(
      _Symbol,
      _Period,
      name,
      UseIndicator1,
      (int)Indicator1_Mode,
      Indicator1_Name,
      Indicator1_BuyBuffer,
      Indicator1_SellBuffer,
      UseIndicator2,
      (int)Indicator2_Mode,
      Indicator2_Name,
      Indicator2_BuyBuffer,
      Indicator2_SellBuffer,
      UseTrendIndicator,
      UseTrendLineFilter,
      (int)TrendSource,
      TrendMA_Period,
      TrendMA_Method,
      TrendMA_AppliedPrice,
      TrendIndicator_Name,
      TrendIndicator_Buffer,
      (int)TrendCompareWith,
      (int)TrendSideRule,
      UseTrendAngleFilter,
      TrendAnglePeriod,
      AngleBuyFrom,
      AngleBuyTo,
      AngleSellFrom,
      AngleSellTo,
      UseTrendLineCross,
      (int)TrendCrossRole,
      TrendLine1_Buffer,
      TrendLine2_Buffer,
      StatsLookbackBars,
      BarsForward,
      IgnoreZeroValues,
      UseDayFilter,
      Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday,
      UseTimeFilter,
      StartHour, StartMinute, EndHour, EndMinute,
      true,   // ShowSignalArrows — required to write BUY/SELL buffers
      false,  // ShowResultArrows
      false,  // ShowTrendLine
      false,  // ShowStatistics
      false,  // ShowPipLabels
      0,      // MaxPipLabels
      false,  // ShowCandleTimer
      clrNONE,
      8,
      12,
      18,
      (int)UNIT_PIPS,
      8,
      clrNONE,
      clrNONE
   );
   if(h == INVALID_HANDLE)
   {
      Print("EA: iCustom failed name=", name, " err=", GetLastError(),
            "  Ind1=", Indicator1_Name, " use1=", UseIndicator1,
            "  Ind2=", Indicator2_Name, " use2=", UseIndicator2);
   }
   else
   {
      g_handleSource = "file:" + name;
      Print("EA: loaded Combiner file ", name, " handle=", h);
   }
   return h;
}

void ReleaseOurHandle()
{
   if(g_handle != INVALID_HANDLE && !g_handleFromChart)
      IndicatorRelease(g_handle);
   g_handle = INVALID_HANDLE;
   g_handleFromChart = false;
   g_handleSource = "";
}

bool EnsureCombinerHandle()
{
   if(g_handle != INVALID_HANDLE)
      return true;

   if(g_lastRetry != 0 && TimeCurrent() == g_lastRetry)
      return false;
   g_lastRetry = TimeCurrent();

   int h = INVALID_HANDLE;
   bool fromChart = false;

   if(CombinerSource != COMBINER_FILE_ONLY)
   {
      h = FindChartCombiner();
      fromChart = (h != INVALID_HANDLE);
   }

   if(h == INVALID_HANDLE && CombinerSource != COMBINER_CHART_ONLY)
   {
      string names[4];
      names[0] = CombinerName;
      names[1] = "StrategyCombiner_v1";
      names[2] = CombinerName + ".ex5";
      names[3] = "StrategyCombiner_v1.ex5";
      for(int i = 0; i < 4; i++)
      {
         if(names[i] == "")
            continue;
         if(i > 0 && names[i] == names[0])
            continue;
         h = LoadCombinerFile(names[i]);
         if(h != INVALID_HANDLE)
            break;
      }
      fromChart = false;
   }

   if(h == INVALID_HANDLE)
   {
      g_lastError = "Combiner load failed. Compile Indicators/StrategyCombiner_v1.mq5 OR drop Combiner on this chart. If UseIndicator2=true, that file must exist.";
      return false;
   }

   if(g_handle != INVALID_HANDLE && g_handle != h)
      ReleaseOurHandle();

   g_handle = h;
   g_handleFromChart = fromChart;
   g_lastError = "";
   return true;
}

void DeleteStatusPanel()
{
   ObjectsDeleteAll(0, SC_EA_STATUS_NAME);
}

void UpdateStatusPanel(const string text)
{
   if(!ShowStatusPanel)
   {
      DeleteStatusPanel();
      return;
   }

   string lines[];
   const int n = StringSplit(text, '\n', lines);
   for(int i = 0; i < n; i++)
   {
      const string name = SC_EA_STATUS_NAME + IntegerToString(i);
      if(ObjectFind(0, name) < 0)
      {
         if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
            continue;
      }
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 8);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 16 + i * 16);
      ObjectSetString(0, name, OBJPROP_TEXT, lines[i]);
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, name, OBJPROP_COLOR, (StringFind(lines[i], "ERR") == 0) ? clrOrangeRed : C'0,230,180');
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
   }

   for(int i = n; i < 16; i++)
      ObjectDelete(0, SC_EA_STATUS_NAME + IntegerToString(i));
}

string SignalText(const int s)
{
   if(s > 0) return "BUY";
   if(s < 0) return "SELL";
   return "NONE";
}

int ReadClosedBarSignal(string &note)
{
   if(g_handle == INVALID_HANDLE)
   {
      note = "no combiner handle";
      return 0;
   }

   const int calc = BarsCalculated(g_handle);
   if(calc <= 0)
   {
      note = "combiner not calculated yet (" + IntegerToString(calc) + ")";
      return 0;
   }
   if(calc < BarsForward + 5)
   {
      note = "not enough calculated bars " + IntegerToString(calc);
      return 0;
   }

   double buy[], sell[];
   ArrayResize(buy, 3);
   ArrayResize(sell, 3);
   ArraySetAsSeries(buy, true);
   ArraySetAsSeries(sell, true);

   const int cb = CopyBuffer(g_handle, 0, 0, 3, buy);
   const int cs = CopyBuffer(g_handle, 1, 0, 3, sell);
   if(cb < 2 || cs < 2)
   {
      note = "CopyBuffer failed buy=" + IntegerToString(cb) + " sell=" + IntegerToString(cs);
      return 0;
   }

   const bool buySig  = IsSignalValue(buy[1]);
   const bool sellSig = IsSignalValue(sell[1]);
   note = "buyBuf=" + (buySig ? "Y" : "N") + " sellBuf=" + (sellSig ? "Y" : "N");

   if(buySig && !sellSig)
      return 1;
   if(sellSig && !buySig)
      return -1;
   return 0;
}

bool IsNewBar()
{
   datetime t = iTime(_Symbol, _Period, 0);
   if(t <= 0)
      return false;
   if(t == g_lastBar)
      return false;
   g_lastBar = t;
   return true;
}

int CountMyPositions(const int typeFilter = -1)
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;
      if(typeFilter >= 0 && (int)PositionGetInteger(POSITION_TYPE) != typeFilter)
         continue;
      n++;
   }
   return n;
}

void CloseMyPositions(const int typeFilter = -1)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;
      if(typeFilter >= 0 && (int)PositionGetInteger(POSITION_TYPE) != typeFilter)
         continue;
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
      if(t > 0)
         return (datetime)t;
   }
   return (datetime)PositionGetInteger(POSITION_TIME);
}

bool PositionHasEncodedSignalBar()
{
   string c = PositionGetString(POSITION_COMMENT);
   return (StringFind(c, "|") >= 0);
}

bool NBarsCompleted(const datetime signalOrEntry, const bool encodedSignalBar)
{
   int n = BarsForward;
   if(n < 1)
      n = 1;

   int sh = iBarShift(_Symbol, _Period, signalOrEntry, false);
   if(sh < 0)
      return false;

   if(encodedSignalBar)
      return (sh >= n + 1);
   return (sh >= n);
}

void CloseExpiredNBarPositions()
{
   if(!CloseAfterNBars)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;

      datetime mark = PositionSignalBarTime();
      bool encoded = PositionHasEncodedSignalBar();
      if(!NBarsCompleted(mark, encoded))
         continue;

      if(trade.PositionClose(ticket))
      {
         g_lastAction = "closed after N=" + IntegerToString(BarsForward) + " ticket=" + IntegerToString((long)ticket);
         Print("EA: ", g_lastAction);
      }
      else
      {
         g_lastAction = "N-bar close failed " + trade.ResultRetcodeDescription();
         Print("EA: ", g_lastAction);
      }
   }
}

double NormalizeLot(double lot)
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0)
      step = 0.01;
   lot = MathFloor(lot / step + 1e-12) * step;
   if(lot < minLot)
      lot = minLot;
   if(lot > maxLot)
      lot = maxLot;
   int digits = 2;
   if(step < 0.01)
      digits = 3;
   if(step < 0.001)
      digits = 4;
   return NormalizeDouble(lot, digits);
}

double CalcLot(const double slPrice, const bool isBuy)
{
   if(LotMode == LOT_FIXED || StopLossPoints <= 0 || slPrice <= 0.0)
      return NormalizeLot(FixedLot);

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * RiskPercent / 100.0;
   double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickVal <= 0.0 || tickSize <= 0.0)
      return NormalizeLot(FixedLot);

   double price = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double slDist = MathAbs(price - slPrice);
   if(slDist <= 0.0)
      return NormalizeLot(FixedLot);

   double lossPerLot = (slDist / tickSize) * tickVal;
   if(lossPerLot <= 0.0)
      return NormalizeLot(FixedLot);
   return NormalizeLot(riskMoney / lossPerLot);
}

bool SpreadOk()
{
   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (MaxSpreadPoints <= 0 || spread <= MaxSpreadPoints);
}

bool SendOrder(const int signal, const double lot, const double sl, const double tp, const string comment)
{
   const ENUM_ORDER_TYPE_FILLING fills[3] =
   {
      ORDER_FILLING_IOC,
      ORDER_FILLING_FOK,
      ORDER_FILLING_RETURN
   };

   for(int i = 0; i < 3; i++)
   {
      trade.SetTypeFilling(fills[i]);
      bool ok = false;
      if(signal == 1)
         ok = trade.Buy(lot, _Symbol, 0.0, sl, tp, comment);
      else
         ok = trade.Sell(lot, _Symbol, 0.0, sl, tp, comment);
      if(ok)
         return true;

      const uint rc = trade.ResultRetcode();
      Print("EA order try fill=", fills[i], " rc=", rc, " ", trade.ResultRetcodeDescription());
      if(rc != TRADE_RETCODE_INVALID_FILL)
         break;
   }
   return false;
}

bool OpenTrade(const int signal, const datetime signalBar)
{
   if(signal == 1 && !AllowBuy)
   {
      g_lastAction = "BUY blocked by AllowBuy=false";
      return false;
   }
   if(signal == -1 && !AllowSell)
   {
      g_lastAction = "SELL blocked by AllowSell=false";
      return false;
   }

   string why;
   if(!TradeAllowed(why))
   {
      g_lastAction = "trade not allowed: " + why;
      Print("EA: ", g_lastAction);
      return false;
   }

   if(!SpreadOk())
   {
      g_lastAction = "spread too high " + IntegerToString((int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD));
      Print("EA: ", g_lastAction);
      return false;
   }

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   string comment = BuildTradeComment(signalBar);

   double sl = 0.0, tp = 0.0;
   if(signal == 1)
   {
      if(StopLossPoints > 0)
         sl = NormalizeDouble(ask - StopLossPoints * point, digits);
      if(TakeProfitPoints > 0)
         tp = NormalizeDouble(ask + TakeProfitPoints * point, digits);
   }
   else
   {
      if(StopLossPoints > 0)
         sl = NormalizeDouble(bid + StopLossPoints * point, digits);
      if(TakeProfitPoints > 0)
         tp = NormalizeDouble(bid - TakeProfitPoints * point, digits);
   }

   double lot = CalcLot(sl, signal == 1);
   if(lot <= 0.0)
   {
      g_lastAction = "invalid lot";
      return false;
   }

   if(!SendOrder(signal, lot, sl, tp, comment))
   {
      g_lastAction = "order failed " + IntegerToString((int)trade.ResultRetcode()) +
                     " " + trade.ResultRetcodeDescription();
      Print("EA: ", g_lastAction);
      return false;
   }

   g_lastAction = SignalText(signal) + " opened lot=" + DoubleToString(lot, 2) +
                  " hold=" + IntegerToString(BarsForward) + " bars";
   Print("EA: ", g_lastAction);
   return true;
}

void ProcessSignal(const int signal)
{
   if(signal == 0)
      return;

   datetime closedBar = iTime(_Symbol, _Period, 1);
   if(closedBar > 0 && closedBar == g_lastSignalBar)
      return;

   if(CloseOpposite)
   {
      if(signal == 1)
         CloseMyPositions(POSITION_TYPE_SELL);
      else
         CloseMyPositions(POSITION_TYPE_BUY);
   }

   if(OnePositionOnly && CountMyPositions() > 0)
   {
      g_lastAction = "signal " + SignalText(signal) + " skipped: already in position";
      return;
   }

   if(OpenTrade(signal, closedBar))
      g_lastSignalBar = closedBar;
}

void RefreshStatus(const int signal, const string sigNote, const bool tradingNow)
{
   string why;
   TradeAllowed(why);
   const int calc = (g_handle == INVALID_HANDLE) ? -1 : BarsCalculated(g_handle);
   const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);

   string text =
      "SC EA v1.20  " + _Symbol + " " + EnumToString(_Period) + "\n" +
      "source : " + (g_handleSource == "" ? "NONE" : g_handleSource) + "\n" +
      "calc   : " + IntegerToString(calc) + "   handle=" + IntegerToString(g_handle) + "\n" +
      "signal : " + SignalText(signal) + "  (" + sigNote + ")\n" +
      "exit   : after " + IntegerToString(BarsForward) + " candles\n" +
      "pos    : " + IntegerToString(CountMyPositions()) +
      "   spread=" + IntegerToString((int)spread) + "\n" +
      "algo   : " + why + "\n" +
      "work   : " + (tradingNow ? "checking bar" : "wait new bar") + "\n" +
      "last   : " + g_lastAction;

   if(g_lastError != "")
      text += "\nERR: " + g_lastError;

   UpdateStatusPanel(text);
}

void RunEA(const bool tradingNow)
{
   EnsureCombinerHandle();

   string sigNote = "";
   const int signal = ReadClosedBarSignal(sigNote);

   if(tradingNow)
   {
      CloseExpiredNBarPositions();
      ProcessSignal(signal);
   }

   RefreshStatus(signal, sigNote, tradingNow);
}

int OnInit()
{
   if(BarsForward < 1)
   {
      Print("ERROR: BarsForward must be >= 1");
      return INIT_FAILED;
   }

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(SlippagePoints);
   SetupFilling();

   g_startCheckDone = false;
   g_lastBar = 0;
   g_lastRetry = 0;
   g_lastAction = "started";

   EnsureCombinerHandle();
   if(g_handle == INVALID_HANDLE)
   {
      Print("EA WARNING: Combiner not loaded yet. EA stays on chart and retries. ", g_lastError);
      Print("Tip: drop StrategyCombiner_v1 on this same chart, or compile it in MQL5/Indicators/.");
      Print("If you do not use a second indicator, set UseIndicator2=false.");
   }

   EventSetTimer(1);
   RunEA(false);

   string why;
   TradeAllowed(why);
   Print("StrategyCombiner EA ready. source=", g_handleSource,
         " algo=", why, " exit N=", BarsForward);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   DeleteStatusPanel();
   ReleaseOurHandle();
}

void OnTimer()
{
   const bool newBar = IsNewBar();
   bool tradingNow = false;
   if(TradeClosedBarOnStart && !g_startCheckDone)
   {
      tradingNow = true;
      g_startCheckDone = true;
   }
   else if(!TradeOnlyNewBar || newBar)
      tradingNow = true;

   RunEA(tradingNow);
}

void OnTick()
{
   const bool newBar = IsNewBar();
   bool tradingNow = false;
   if(TradeClosedBarOnStart && !g_startCheckDone)
   {
      tradingNow = true;
      g_startCheckDone = true;
   }
   else if(!TradeOnlyNewBar || newBar)
      tradingNow = true;

   RunEA(tradingNow);
}
//+------------------------------------------------------------------+
