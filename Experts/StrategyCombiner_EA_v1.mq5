//+------------------------------------------------------------------+
//| StrategyCombiner_EA_v1.mq5                                       |
//| Auto-trader for StrategyCombiner_v1                              |
//| Exit after BarsForward candles. Indicator file is not modified.  |
//+------------------------------------------------------------------+
#property strict
#property copyright "Strategy Combiner"
#property version   "1.30"
#property description "Auto trader + debug window for StrategyCombiner_v1"
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
   COMBINER_CHART_THEN_FILE = 0,
   COMBINER_CHART_ONLY      = 1,
   COMBINER_FILE_ONLY       = 2,
   COMBINER_DIRECT_ONLY     = 3  // مستقیم از Ind1/Ind2 بدون Combiner.ex5
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
input bool           UseIndicator2         = false;
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
input int    BarsForward       = 2;
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

input group "=== Auto Trade ==="
input bool         AllowBuy           = true;
input bool         AllowSell          = true;
input bool         CloseAfterNBars    = true;
input bool         CloseOpposite      = false;
input bool         OnePositionOnly    = true;
input bool         TradeOnlyNewBar    = true;
input bool         TradeClosedBarOnStart = true;
input int          MaxSpreadPoints    = 40;
input ulong        MagicNumber        = 20260814;
input int          SlippagePoints     = 20;
input string       TradeComment       = "SC_EA_v1";

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

input group "=== Debug ==="
input bool   ShowDebugWindow  = true;
input bool   DebugPopup       = true;   // پنجره MessageBox وقتی خطا باشد
input bool   DebugLogToFile   = true;   // فایل Common/Files/SC_EA_debug.log


#define SC_DBG_BG    "SC_EA_DBG_BG"
#define SC_DBG_LINE  "SC_EA_DBG_"
#define SC_DBG_FILE  "SC_EA_debug.log"
#define SC_COPY_BARS 12

CTrade   trade;
int      g_handle = INVALID_HANDLE;
bool     g_handleFromChart = false;
string   g_handleSource = "";
string   g_lastError = "";
string   g_lastAction = "init";
string   g_debugReport = "";
datetime g_lastBar = 0;
datetime g_lastSignalBar = 0;
datetime g_lastRetry = 0;
bool     g_startCheckDone = false;
bool     g_popupShown = false;
bool     g_useDirect = false;

int      g_h1 = INVALID_HANDLE;
int      g_h2 = INVALID_HANDLE;
int      g_hTrend = INVALID_HANDLE;
bool     g_ownH1 = false;
bool     g_ownH2 = false;
bool     g_ownTrend = false;

string   g_path1 = "";
string   g_path2 = "";
string   g_pathTrend = "";
string   g_pathComb = "";

int      g_err1 = 0;
int      g_err2 = 0;
int      g_errTrend = 0;
int      g_errComb = 0;

string   g_chartList = "";


//==================================================================
//  DEBUG / PATH HELPERS
//==================================================================
string ExplainError(const int e)
{
   switch(e)
   {
      case 0:    return "OK";
      case 4002: return "4002 wrong parameter";
      case 4003: return "4003 invalid parameter";
      case 4801: return "4801 unknown symbol";
      case 4802: return "4802 cannot create (file not found OR indicator OnInit failed)";
      case 4803: return "4803 not enough memory";
      case 4804: return "4804 shortname error";
      case 4805: return "4805 cannot apply";
      case 4806: return "4806 wrong buffer index";
      case 5020: return "5020 file not found";
      default:   return IntegerToString(e);
   }
}

string NormalizeIndicatorPath(string p)
{
   StringTrimLeft(p);
   StringTrimRight(p);
   if(p == "")
      return p;

   StringReplace(p, "/", "\\");
   while(StringReplace(p, "\\\\", "\\") > 0)
   {
   }

   const int len = StringLen(p);
   if(len > 4)
   {
      string ext = StringSubstr(p, len - 4);
      StringToLower(ext);
      if(ext == ".ex5" || ext == ".mq5")
         p = StringSubstr(p, 0, len - 4);
   }

   string markers[4];
   markers[0] = "MQL5\\Indicators\\";
   markers[1] = "mql5\\indicators\\";
   markers[2] = "MQL5\\indicators\\";
   markers[3] = "mql5\\Indicators\\";
   for(int i = 0; i < 4; i++)
   {
      int k = StringFind(p, markers[i]);
      if(k >= 0)
      {
         p = StringSubstr(p, k + StringLen(markers[i]));
         break;
      }
   }

   if(StringFind(p, "Indicators\\") == 0)
      p = StringSubstr(p, 11);

   if(StringFind(p, "\\") == 0)
      p = StringSubstr(p, 1);

   return p;
}

void DbgPrint(const string msg)
{
   Print("SC-EA ", msg);
   if(!DebugLogToFile)
      return;
   int fh = FileOpen(SC_DBG_FILE, FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(fh == INVALID_HANDLE)
      return;
   FileSeek(fh, 0, SEEK_END);
   FileWriteString(fh, TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS) + "  " + msg + "\n");
   FileClose(fh);
}

void CollectChartIndicators()
{
   g_chartList = "";
   const int windows = (int)ChartGetInteger(0, CHART_WINDOWS_TOTAL);
   for(int w = 0; w < windows; w++)
   {
      const int total = ChartIndicatorsTotal(0, w);
      for(int i = 0; i < total; i++)
      {
         const string name = ChartIndicatorName(0, w, i);
         if(name == "")
            continue;
         if(g_chartList != "")
            g_chartList += " | ";
         g_chartList += "[" + IntegerToString(w) + ":" + IntegerToString(i) + "] " + name;
      }
   }
   if(g_chartList == "")
      g_chartList = "(none on this chart)";
}

int ProbeCustom(const string name, int &err)
{
   ResetLastError();
   const int h = iCustom(_Symbol, _Period, name);
   err = GetLastError();
   if(h == INVALID_HANDLE && err == 0)
      err = 4802;
   return h;
}

void ReleaseIfOwn(int &h, bool &own)
{
   if(h != INVALID_HANDLE && own)
      IndicatorRelease(h);
   h = INVALID_HANDLE;
   own = false;
}

bool SlotIsSignalSource(const bool used, const ENUM_SLOT_MODE mode)
{
   return used && (mode == SLOT_MODE_BUFFERS || mode == SLOT_MODE_CROSS_SIGNAL);
}

bool SlotIsTrendSource(const bool used, const ENUM_SLOT_MODE mode)
{
   return used && mode == SLOT_MODE_CROSS_TREND;
}

bool IsFiniteNumber(const double value)
{
   if(value == EMPTY_VALUE || value == DBL_MAX)
      return false;
   return MathIsValidNumber(value);
}

bool IsSignalValue(const double v)
{
   if(!IsFiniteNumber(v))
      return false;
   if(IgnoreZeroValues && v == 0.0)
      return false;
   return true;
}

bool IsAllowedDay(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   switch(dt.day_of_week)
   {
      case 0: return Sunday;
      case 1: return Monday;
      case 2: return Tuesday;
      case 3: return Wednesday;
      case 4: return Thursday;
      case 5: return Friday;
      case 6: return Saturday;
   }
   return false;
}

bool IsAllowedTime(const datetime t)
{
   if(UseDayFilter && !IsAllowedDay(t))
      return false;
   if(!UseTimeFilter)
      return true;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   int currentMinutes = dt.hour * 60 + dt.min;
   int startMinutes   = StartHour * 60 + StartMinute;
   int endMinutes     = EndHour * 60 + EndMinute;
   if(startMinutes <= endMinutes)
      return (currentMinutes >= startMinutes && currentMinutes <= endMinutes);
   return (currentMinutes >= startMinutes || currentMinutes <= endMinutes);
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
   { why = "terminal not connected"; return false; }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   { why = "AutoTrading OFF (toolbar)"; return false; }
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
   { why = "Allow Algo Trading checkbox OFF"; return false; }
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
   { why = "account trading disabled"; return false; }
   if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
   { why = "account experts disabled"; return false; }
   if(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_DISABLED)
   { why = "symbol trade disabled"; return false; }
   why = "OK";
   return true;
}


//==================================================================
//  DEBUG WINDOW
//==================================================================
void DeleteDebugWindow()
{
   ObjectDelete(0, SC_DBG_BG);
   ObjectsDeleteAll(0, SC_DBG_LINE);
}

void DrawDebugWindow(const string text)
{
   if(!ShowDebugWindow)
   {
      DeleteDebugWindow();
      return;
   }

   string lines[];
   int n = StringSplit(text, '\n', lines);
   if(n < 1)
      n = 1;
   if(n > 32)
      n = 32;

   const int width = 620;
   const int lineH = 15;
   const int height = 18 + n * lineH + 10;

   if(ObjectFind(0, SC_DBG_BG) < 0)
      ObjectCreate(0, SC_DBG_BG, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, SC_DBG_BG, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, SC_DBG_BG, OBJPROP_XDISTANCE, 6);
   ObjectSetInteger(0, SC_DBG_BG, OBJPROP_YDISTANCE, 14);
   ObjectSetInteger(0, SC_DBG_BG, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, SC_DBG_BG, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, SC_DBG_BG, OBJPROP_BGCOLOR, C'12,18,28');
   ObjectSetInteger(0, SC_DBG_BG, OBJPROP_COLOR, C'0,160,130');
   ObjectSetInteger(0, SC_DBG_BG, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, SC_DBG_BG, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, SC_DBG_BG, OBJPROP_BACK, false);
   ObjectSetInteger(0, SC_DBG_BG, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, SC_DBG_BG, OBJPROP_HIDDEN, true);

   for(int i = 0; i < n; i++)
   {
      const string name = SC_DBG_LINE + IntegerToString(i);
      if(ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      color clr = C'180,240,220';
      if(i == 0)
         clr = C'255,220,80';
      if(StringFind(lines[i], "FAIL") >= 0 || StringFind(lines[i], "ERR") >= 0)
         clr = C'255,90,70';
      else if(StringFind(lines[i], "OK") >= 0 || StringFind(lines[i], "BUY") >= 0)
         clr = C'80,230,140';

      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 14);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 20 + i * lineH);
      ObjectSetString(0, name, OBJPROP_TEXT, lines[i]);
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
   }
   for(int i = n; i < 32; i++)
      ObjectDelete(0, SC_DBG_LINE + IntegerToString(i));
}

void ShowDebugPopup(const string title, const string body)
{
   if(!DebugPopup)
      return;
   if(g_popupShown)
      return;
   if(MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION))
      return;
   g_popupShown = true;
   MessageBox(body, title, MB_OK | MB_ICONINFORMATION);
}


//==================================================================
//  LOAD COMBINER / CHILDREN
//==================================================================
int FindChartCombiner()
{
   CollectChartIndicators();
   const int windows = (int)ChartGetInteger(0, CHART_WINDOWS_TOTAL);
   for(int w = 0; w < windows; w++)
   {
      const int total = ChartIndicatorsTotal(0, w);
      for(int i = 0; i < total; i++)
      {
         const string name = ChartIndicatorName(0, w, i);
         if(name == "")
            continue;
         if(StringFind(name, CombinerShortName) < 0 &&
            StringFind(name, "StrategyCombiner") < 0 &&
            StringFind(name, "Strategy Combiner") < 0 &&
            StringFind(name, CombinerName) < 0)
            continue;
         const int h = ChartIndicatorGet(0, w, name);
         if(h != INVALID_HANDLE)
         {
            g_handleSource = "chart w" + IntegerToString(w) + ":" + name;
            DbgPrint("using chart Combiner " + name + " handle=" + IntegerToString(h));
            return h;
         }
      }
   }
   return INVALID_HANDLE;
}

int LoadCombinerFile(const string name, int &err)
{
   ResetLastError();
   const int h = iCustom(
      _Symbol, _Period, name,
      UseIndicator1, (int)Indicator1_Mode, g_path1, Indicator1_BuyBuffer, Indicator1_SellBuffer,
      UseIndicator2, (int)Indicator2_Mode, g_path2, Indicator2_BuyBuffer, Indicator2_SellBuffer,
      UseTrendIndicator, UseTrendLineFilter, (int)TrendSource,
      TrendMA_Period, TrendMA_Method, TrendMA_AppliedPrice,
      g_pathTrend, TrendIndicator_Buffer, (int)TrendCompareWith, (int)TrendSideRule,
      UseTrendAngleFilter, TrendAnglePeriod, AngleBuyFrom, AngleBuyTo, AngleSellFrom, AngleSellTo,
      UseTrendLineCross, (int)TrendCrossRole, TrendLine1_Buffer, TrendLine2_Buffer,
      StatsLookbackBars, BarsForward, IgnoreZeroValues,
      UseDayFilter, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday,
      UseTimeFilter, StartHour, StartMinute, EndHour, EndMinute,
      true, false, false, false, false, 0, false,
      clrNONE, 8, 12, 18, (int)UNIT_PIPS, 8, clrNONE, clrNONE
   );
   err = GetLastError();
   if(h == INVALID_HANDLE && err == 0)
      err = 4802;
   DbgPrint("iCustom Combiner '" + name + "' h=" + IntegerToString(h) + " " + ExplainError(err));
   return h;
}

bool LoadDirectHandles()
{
   if(UseIndicator1 && g_h1 == INVALID_HANDLE)
   {
      g_h1 = ProbeCustom(g_path1, g_err1);
      g_ownH1 = (g_h1 != INVALID_HANDLE);
      DbgPrint("Ind1 '" + g_path1 + "' (raw='" + Indicator1_Name + "') " + ExplainError(g_err1) + " h=" + IntegerToString(g_h1));
   }
   else if(!UseIndicator1)
      g_err1 = 0;

   if(UseIndicator2 && g_h2 == INVALID_HANDLE)
   {
      g_h2 = ProbeCustom(g_path2, g_err2);
      g_ownH2 = (g_h2 != INVALID_HANDLE);
      DbgPrint("Ind2 '" + g_path2 + "' (raw='" + Indicator2_Name + "') " + ExplainError(g_err2) + " h=" + IntegerToString(g_h2));
   }
   else if(!UseIndicator2)
      g_err2 = 0;

   if((UseTrendIndicator || UseTrendAngleFilter) && g_hTrend == INVALID_HANDLE)
   {
      ResetLastError();
      if(TrendSource == TREND_SOURCE_MA)
         g_hTrend = iMA(_Symbol, _Period, TrendMA_Period, 0, TrendMA_Method, TrendMA_AppliedPrice);
      else
         g_hTrend = ProbeCustom(g_pathTrend, g_errTrend);
      g_errTrend = GetLastError();
      g_ownTrend = (g_hTrend != INVALID_HANDLE);
      DbgPrint("Trend " + ExplainError(g_errTrend) + " h=" + IntegerToString(g_hTrend));
   }

   const bool ok1 = (!UseIndicator1 || g_h1 != INVALID_HANDLE);
   const bool ok2 = (!UseIndicator2 || g_h2 != INVALID_HANDLE);
   const bool okT = (!(UseTrendIndicator || UseTrendAngleFilter) || g_hTrend != INVALID_HANDLE);
   return (ok1 && ok2 && okT);
}

void ReleaseOurHandle()
{
   if(g_handle != INVALID_HANDLE && !g_handleFromChart)
      IndicatorRelease(g_handle);
   g_handle = INVALID_HANDLE;
   g_handleFromChart = false;
   g_handleSource = "";
}

void ReleaseDirect()
{
   ReleaseIfOwn(g_h1, g_ownH1);
   ReleaseIfOwn(g_h2, g_ownH2);
   ReleaseIfOwn(g_hTrend, g_ownTrend);
}

void BuildLoadReport()
{
   string why;
   TradeAllowed(why);

   g_debugReport =
      "SC EA v1.30 DEBUG   " + _Symbol + " " + EnumToString(_Period) + "\n" +
      "------------------------------------------------" + "\n" +
      "Ind1 use=" + (UseIndicator1 ? "Y" : "N") + " raw=[" + Indicator1_Name + "]\n" +
      "     path=[" + g_path1 + "]  " + (UseIndicator1 ? ExplainError(g_err1) : "skipped") + "\n" +
      "Ind2 use=" + (UseIndicator2 ? "Y" : "N") + " raw=[" + Indicator2_Name + "]\n" +
      "     path=[" + g_path2 + "]  " + (UseIndicator2 ? ExplainError(g_err2) : "skipped") + "\n" +
      "Trend " + ExplainError(g_errTrend) + "   Combiner " + ExplainError(g_errComb) + "\n" +
      "Combiner path=[" + g_pathComb + "]\n" +
      "source=" + (g_handleSource == "" ? "NONE" : g_handleSource) +
      "  direct=" + (g_useDirect ? "Y" : "N") + "\n" +
      "chart indicators: " + g_chartList + "\n" +
      "algo=" + why + "  last=" + g_lastAction;

   if(g_lastError != "")
      g_debugReport += "\nERR: " + g_lastError;
}

void MaybePopupLoadError()
{
   const bool fail =
      (UseIndicator1 && g_h1 == INVALID_HANDLE && g_handle == INVALID_HANDLE) ||
      (UseIndicator2 && g_h2 == INVALID_HANDLE && g_handle == INVALID_HANDLE) ||
      (g_handle == INVALID_HANDLE && !g_useDirect);

   if(!fail)
      return;

   string body =
      "گزارش خطای StrategyCombiner EA\n\n" +
      "Ind1:\n  واردشده: " + Indicator1_Name + "\n  نرمال‌شده: " + g_path1 + "\n  نتیجه: " + ExplainError(g_err1) + "\n\n" +
      "Ind2:\n  واردشده: " + Indicator2_Name + "\n  نرمال‌شده: " + g_path2 + "\n  نتیجه: " + ExplainError(g_err2) + "\n\n" +
      "Combiner [" + g_pathComb + "]: " + ExplainError(g_errComb) + "\n" +
      "اندیکاتورهای روی چارت:\n" + g_chartList + "\n\n" +
      "نکته مهم:\n" +
      "iCustom فقط مسیر نسبی داخل پوشه MQL5\\Indicators می‌خواهد.\n" +
      "درست:  Market\\Dark Bands MT5\n" +
      "غلط:   C:\\Users\\...\\MQL5\\Indicators\\Market\\...\n\n" +
      "اگر Combiner روی همین چارت باشد، EA از همان می‌خواند.\n" +
      "جزئیات بیشتر: Experts journal و فایل Common\\Files\\SC_EA_debug.log";

   ShowDebugPopup("StrategyCombiner EA — خطا", body);
}

bool EnsureHandles()
{
   if(g_handle != INVALID_HANDLE || g_useDirect)
      return true;

   if(g_lastRetry != 0 && TimeCurrent() == g_lastRetry)
      return false;
   g_lastRetry = TimeCurrent();

   g_path1    = NormalizeIndicatorPath(Indicator1_Name);
   g_path2    = NormalizeIndicatorPath(Indicator2_Name);
   g_pathTrend= NormalizeIndicatorPath(TrendIndicator_Name);
   g_pathComb = NormalizeIndicatorPath(CombinerName);

   CollectChartIndicators();
   LoadDirectHandles();

   int h = INVALID_HANDLE;
   bool fromChart = false;

   if(CombinerSource != COMBINER_FILE_ONLY && CombinerSource != COMBINER_DIRECT_ONLY)
   {
      h = FindChartCombiner();
      fromChart = (h != INVALID_HANDLE);
   }

   if(h == INVALID_HANDLE && CombinerSource != COMBINER_CHART_ONLY && CombinerSource != COMBINER_DIRECT_ONLY)
   {
      string names[4];
      names[0] = g_pathComb;
      names[1] = "StrategyCombiner_v1";
      names[2] = g_pathComb + ".ex5";
      names[3] = "StrategyCombiner_v1.ex5";
      for(int i = 0; i < 4; i++)
      {
         if(names[i] == "")
            continue;
         if(i > 0 && names[i] == names[0])
            continue;
         h = LoadCombinerFile(names[i], g_errComb);
         if(h != INVALID_HANDLE)
            break;
      }
      fromChart = false;
   }

   if(h != INVALID_HANDLE)
   {
      g_handle = h;
      g_handleFromChart = fromChart;
      if(!fromChart)
         g_handleSource = "file:" + g_pathComb;
      g_useDirect = false;
      g_lastError = "";
      g_errComb = 0;
      return true;
   }

   // Combiner.ex5 failed — trade with the same Ind1/Ind2/Trend logic directly.
   const bool hasSignal =
      SlotIsSignalSource(UseIndicator1, Indicator1_Mode) ||
      SlotIsSignalSource(UseIndicator2, Indicator2_Mode) ||
      (UseTrendLineCross && TrendCrossRole == TREND_CROSS_SIGNAL);

   if(hasSignal && LoadDirectHandles())
   {
      g_useDirect = true;
      g_handleSource = "direct Ind1/Ind2";
      g_lastError = "Combiner.ex5 load failed (" + ExplainError(g_errComb) +
                    ") — EA switched to DIRECT mode using your Ind1/Ind2 paths.";
      DbgPrint(g_lastError);
      if(DebugPopup && !g_popupShown && !MQLInfoInteger(MQL_TESTER))
      {
         g_popupShown = true;
         MessageBox(
            "Combiner.ex5 لود نشد: " + ExplainError(g_errComb) + "\n\n" +
            "اکسپرت قطع نشد و روی حالت DIRECT رفت.\n" +
            "سیگنال را مستقیم از Ind1 / Ind2 می‌خواند.\n\n" +
            "Ind1 [" + g_path1 + "]: " + ExplainError(g_err1) + "\n" +
            "Ind2 [" + g_path2 + "]: " + ExplainError(g_err2) + "\n\n" +
            "اگر می‌خواهی از خود Combiner روی چارت بخواند،\n" +
            "StrategyCombiner_v1 را روی همین چارت بینداز و EA را یک‌بار Remove/Attach کن.\n\n" +
            "جزئیات: پنل دیباگ روی چارت و Common\\Files\\SC_EA_debug.log",
            "StrategyCombiner EA — حالت DIRECT",
            MB_OK | MB_ICONINFORMATION
         );
      }
      return true;
   }

   g_lastError = "Load failed. Combiner=" + ExplainError(g_errComb) +
                 " Ind1=" + ExplainError(g_err1) +
                 " Ind2=" + ExplainError(g_err2) +
                 " | use relative path inside MQL5\\Indicators";
   DbgPrint(g_lastError);
   return false;
}


//==================================================================
//  DIRECT SIGNAL ENGINE (same rules as Combiner, closed bar only)
//==================================================================
bool CopySeriesBuf(const int handle, const int buf, double &out[])
{
   ArraySetAsSeries(out, true);
   if(handle == INVALID_HANDLE)
   {
      ArrayResize(out, SC_COPY_BARS);
      ArrayInitialize(out, EMPTY_VALUE);
      return false;
   }
   const int n = CopyBuffer(handle, buf, 0, SC_COPY_BARS, out);
   return (n >= 3);
}

bool IsCrossUp(const double &fast[], const double &slow[], const int shift, const int copied)
{
   if(shift < 0 || shift + 1 >= copied) return false;
   if(!IsFiniteNumber(fast[shift]) || !IsFiniteNumber(slow[shift]) ||
      !IsFiniteNumber(fast[shift+1]) || !IsFiniteNumber(slow[shift+1]))
      return false;
   return (fast[shift+1] <= slow[shift+1] && fast[shift] > slow[shift]);
}

bool IsCrossDown(const double &fast[], const double &slow[], const int shift, const int copied)
{
   if(shift < 0 || shift + 1 >= copied) return false;
   if(!IsFiniteNumber(fast[shift]) || !IsFiniteNumber(slow[shift]) ||
      !IsFiniteNumber(fast[shift+1]) || !IsFiniteNumber(slow[shift+1]))
      return false;
   return (fast[shift+1] >= slow[shift+1] && fast[shift] < slow[shift]);
}

int CrossPosition(const double &fast[], const double &slow[], const int shift, const int copied)
{
   if(shift < 0 || shift >= copied) return 0;
   if(!IsFiniteNumber(fast[shift]) || !IsFiniteNumber(slow[shift])) return 0;
   if(fast[shift] > slow[shift]) return 1;
   if(fast[shift] < slow[shift]) return -1;
   return 0;
}

int GetSlotSignal(const bool used, const ENUM_SLOT_MODE mode,
                  const double &fast[], const double &slow[],
                  const int shift, const int copied)
{
   if(!used || shift < 0 || shift >= copied) return 0;
   if(mode == SLOT_MODE_CROSS_TREND) return 0;
   if(mode == SLOT_MODE_CROSS_SIGNAL)
   {
      if(IsCrossUp(fast, slow, shift, copied)) return 1;
      if(IsCrossDown(fast, slow, shift, copied)) return -1;
      return 0;
   }
   const bool buy  = IsSignalValue(fast[shift]);
   const bool sell = IsSignalValue(slow[shift]);
   if(buy && !sell) return 1;
   if(sell && !buy) return -1;
   if(buy && sell) return 1;
   return 0;
}

int ReadDirectSignal(string &note)
{
   if(!IsAllowedTime(iTime(_Symbol, _Period, 1)))
   {
      note = "closed bar blocked by day/hour filter";
      return 0;
   }

   double b1[], s1[], b2[], s2[], tr[], t1[], t2[];
   int c1 = 0, c2 = 0, ct = 0, ct1 = 0, ct2 = 0;

   if(UseIndicator1)
   {
      if(!CopySeriesBuf(g_h1, Indicator1_BuyBuffer, b1) ||
         !CopySeriesBuf(g_h1, Indicator1_SellBuffer, s1))
      {
         note = "Ind1 CopyBuffer failed (wrong buffer # or not calculated)";
         return 0;
      }
      c1 = MathMin(ArraySize(b1), ArraySize(s1));
   }
   if(UseIndicator2)
   {
      if(!CopySeriesBuf(g_h2, Indicator2_BuyBuffer, b2) ||
         !CopySeriesBuf(g_h2, Indicator2_SellBuffer, s2))
      {
         note = "Ind2 CopyBuffer failed (wrong buffer # or not calculated)";
         return 0;
      }
      c2 = MathMin(ArraySize(b2), ArraySize(s2));
   }
   if(UseTrendIndicator || UseTrendAngleFilter)
   {
      const int tb = (TrendSource == TREND_SOURCE_MA) ? 0 : TrendIndicator_Buffer;
      if(!CopySeriesBuf(g_hTrend, tb, tr))
      {
         note = "Trend CopyBuffer failed";
         return 0;
      }
      ct = ArraySize(tr);
   }
   if(UseTrendLineCross)
   {
      CopySeriesBuf(g_h1, TrendLine1_Buffer, t1);
      CopySeriesBuf(g_h2, TrendLine2_Buffer, t2);
      ct1 = ArraySize(t1);
      ct2 = ArraySize(t2);
   }

   const int shift = 1;
   bool hasSignalSlot = false;
   bool wantBuy = true, wantSell = true;

   if(SlotIsSignalSource(UseIndicator1, Indicator1_Mode))
   {
      hasSignalSlot = true;
      int dir = GetSlotSignal(true, Indicator1_Mode, b1, s1, shift, c1);
      if(dir != 1)  wantBuy = false;
      if(dir != -1) wantSell = false;
      note += "I1=" + IntegerToString(dir) + " ";
   }
   if(SlotIsSignalSource(UseIndicator2, Indicator2_Mode))
   {
      hasSignalSlot = true;
      int dir = GetSlotSignal(true, Indicator2_Mode, b2, s2, shift, c2);
      if(dir != 1)  wantBuy = false;
      if(dir != -1) wantSell = false;
      note += "I2=" + IntegerToString(dir) + " ";
   }
   if(UseTrendLineCross && TrendCrossRole == TREND_CROSS_SIGNAL)
   {
      hasSignalSlot = true;
      int copied = MathMin(ct1, ct2);
      int dir = 0;
      if(IsCrossUp(t1, t2, shift, copied)) dir = 1;
      else if(IsCrossDown(t1, t2, shift, copied)) dir = -1;
      if(dir != 1)  wantBuy = false;
      if(dir != -1) wantSell = false;
      note += "X=" + IntegerToString(dir) + " ";
   }

   int signal = 0;
   if(hasSignalSlot)
   {
      if(wantBuy && !wantSell) signal = 1;
      else if(wantSell && !wantBuy) signal = -1;
      else if(wantBuy) signal = 1;
      else if(wantSell) signal = -1;
   }
   if(signal == 0)
   {
      if(note == "") note = "no source signal on closed bar";
      return 0;
   }

   if(SlotIsTrendSource(UseIndicator1, Indicator1_Mode))
   {
      int pos = CrossPosition(b1, s1, shift, c1);
      if(pos == 0 || pos != signal) { note += "I1 trend filter block"; return 0; }
   }
   if(SlotIsTrendSource(UseIndicator2, Indicator2_Mode))
   {
      int pos = CrossPosition(b2, s2, shift, c2);
      if(pos == 0 || pos != signal) { note += "I2 trend filter block"; return 0; }
   }

   if(UseTrendIndicator && UseTrendLineFilter)
   {
      if(shift >= ct || !IsFiniteNumber(tr[shift]))
      { note += "trend empty"; return 0; }
      double refv = iClose(_Symbol, _Period, shift);
      if(TrendCompareWith == TREND_CMP_OPEN) refv = iOpen(_Symbol, _Period, shift);
      else if(TrendCompareWith == TREND_CMP_HIGH) refv = iHigh(_Symbol, _Period, shift);
      else if(TrendCompareWith == TREND_CMP_LOW) refv = iLow(_Symbol, _Period, shift);
      const bool above = (refv > tr[shift]);
      const bool below = (refv < tr[shift]);
      bool ok = false;
      if(TrendSideRule == TREND_BUY_ABOVE_SELL_BELOW)
         ok = ((signal == 1 && above) || (signal == -1 && below));
      else
         ok = ((signal == 1 && below) || (signal == -1 && above));
      if(!ok) { note += "trend line block"; return 0; }
   }

   if(UseTrendAngleFilter)
   {
      int older = shift + TrendAnglePeriod;
      if(older >= ct || !IsFiniteNumber(tr[shift]) || !IsFiniteNumber(tr[older]))
      { note += "angle n/a"; return 0; }
      double pip = (_Digits == 3 || _Digits == 5) ? _Point * 10.0 : _Point;
      if(pip <= 0.0) pip = 1.0;
      double ang = MathArctan((tr[shift] - tr[older]) / (TrendAnglePeriod * pip)) * 180.0 / M_PI;
      bool inBuy  = (ang >= MathMin(AngleBuyFrom, AngleBuyTo) && ang <= MathMax(AngleBuyFrom, AngleBuyTo));
      bool inSell = (ang >= MathMin(AngleSellFrom, AngleSellTo) && ang <= MathMax(AngleSellFrom, AngleSellTo));
      if(signal == 1 && !inBuy) { note += "angle block"; return 0; }
      if(signal == -1 && !inSell) { note += "angle block"; return 0; }
   }

   if(UseTrendLineCross && TrendCrossRole == TREND_CROSS_NEW_TREND)
   {
      int pos = CrossPosition(t1, t2, shift, MathMin(ct1, ct2));
      if(pos == 0 || pos != signal) { note += "new-trend block"; return 0; }
   }

   note += "=> " + ((signal > 0) ? "BUY" : "SELL");
   return signal;
}

int ReadCombinerSignal(string &note)
{
   if(g_handle == INVALID_HANDLE)
   {
      note = "no combiner handle";
      return 0;
   }
   const int calc = BarsCalculated(g_handle);
   if(calc <= 0)
   {
      note = "combiner not calculated (" + IntegerToString(calc) + ")";
      return 0;
   }
   double buy[], sell[];
   ArraySetAsSeries(buy, true);
   ArraySetAsSeries(sell, true);
   const int cb = CopyBuffer(g_handle, 0, 0, 3, buy);
   const int cs = CopyBuffer(g_handle, 1, 0, 3, sell);
   if(cb < 2 || cs < 2)
   {
      note = "CopyBuffer fail buy=" + IntegerToString(cb) + " sell=" + IntegerToString(cs);
      return 0;
   }
   const bool buySig  = IsSignalValue(buy[1]);
   const bool sellSig = IsSignalValue(sell[1]);
   note = "buy=" + (buySig ? "Y" : "N") + " sell=" + (sellSig ? "Y" : "N");
   if(buySig && !sellSig) return 1;
   if(sellSig && !buySig) return -1;
   return 0;
}

int ReadClosedBarSignal(string &note)
{
   note = "";
   if(g_useDirect || CombinerSource == COMBINER_DIRECT_ONLY)
      return ReadDirectSignal(note);
   if(g_handle != INVALID_HANDLE)
      return ReadCombinerSignal(note);
   note = "no signal source loaded";
   return 0;
}


//==================================================================
//  TRADING
//==================================================================
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

bool NBarsCompleted(const datetime signalOrEntry, const bool encodedSignalBar)
{
   int n = (BarsForward < 1) ? 1 : BarsForward;
   int sh = iBarShift(_Symbol, _Period, signalOrEntry, false);
   if(sh < 0) return false;
   return encodedSignalBar ? (sh >= n + 1) : (sh >= n);
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
      datetime mark = PositionSignalBarTime();
      bool encoded = PositionHasEncodedSignalBar();
      if(!NBarsCompleted(mark, encoded)) continue;
      if(trade.PositionClose(ticket))
      {
         g_lastAction = "closed after N=" + IntegerToString(BarsForward);
         DbgPrint(g_lastAction + " ticket=" + IntegerToString((long)ticket));
      }
      else
      {
         g_lastAction = "N-bar close failed " + trade.ResultRetcodeDescription();
         DbgPrint(g_lastAction);
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

bool SpreadOk()
{
   return (MaxSpreadPoints <= 0 || SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) <= MaxSpreadPoints);
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
      uint rc = trade.ResultRetcode();
      DbgPrint("order fill=" + IntegerToString(fills[i]) + " rc=" + IntegerToString(rc) + " " + trade.ResultRetcodeDescription());
      if(rc != TRADE_RETCODE_INVALID_FILL) break;
   }
   return false;
}

bool OpenTrade(const int signal, const datetime signalBar)
{
   if(signal == 1 && !AllowBuy) { g_lastAction = "BUY blocked"; return false; }
   if(signal == -1 && !AllowSell) { g_lastAction = "SELL blocked"; return false; }
   string why;
   if(!TradeAllowed(why))
   {
      g_lastAction = "trade not allowed: " + why;
      DbgPrint(g_lastAction);
      return false;
   }
   if(!SpreadOk())
   {
      g_lastAction = "spread too high " + IntegerToString((int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD));
      DbgPrint(g_lastAction);
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
   if(lot <= 0.0) { g_lastAction = "invalid lot"; return false; }
   if(!SendOrder(signal, lot, sl, tp, BuildTradeComment(signalBar)))
   {
      g_lastAction = "order failed " + IntegerToString((int)trade.ResultRetcode()) +
                     " " + trade.ResultRetcodeDescription();
      if(DebugPopup && !MQLInfoInteger(MQL_TESTER))
         MessageBox(g_lastAction + "\nRetcode=" + IntegerToString((int)trade.ResultRetcode()),
                    "StrategyCombiner EA — سفارش رد شد", MB_OK | MB_ICONERROR);
      return false;
   }
   g_lastAction = SignalText(signal) + " opened lot=" + DoubleToString(lot, 2) +
                  " hold=" + IntegerToString(BarsForward);
   DbgPrint(g_lastAction);
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
      g_lastAction = "signal " + SignalText(signal) + " skipped: already in position";
      return;
   }
   if(OpenTrade(signal, closedBar))
      g_lastSignalBar = closedBar;
}

void RunEA(const bool tradingNow)
{
   EnsureHandles();
   string sigNote = "";
   const int signal = ReadClosedBarSignal(sigNote);
   if(tradingNow)
   {
      CloseExpiredNBarPositions();
      ProcessSignal(signal);
   }

   string why;
   TradeAllowed(why);
   BuildLoadReport();
   string live =
      g_debugReport + "\n" +
      "signal=" + SignalText(signal) + "  (" + sigNote + ")\n" +
      "exit after " + IntegerToString(BarsForward) + " bars   pos=" +
      IntegerToString(CountMyPositions()) + "   spread=" +
      IntegerToString((int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)) + "\n" +
      "work=" + (tradingNow ? "checking bar" : "wait new bar");
   DrawDebugWindow(live);
}

int OnInit()
{
   if(BarsForward < 1)
   {
      MessageBox("BarsForward must be >= 1", "StrategyCombiner EA", MB_OK | MB_ICONERROR);
      return INIT_FAILED;
   }

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(SlippagePoints);
   SetupFilling();

   g_startCheckDone = false;
   g_lastBar = 0;
   g_lastRetry = 0;
   g_popupShown = false;
   g_useDirect = false;
   g_lastAction = "started";

   if(DebugLogToFile)
   {
      int fh = FileOpen(SC_DBG_FILE, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
      if(fh != INVALID_HANDLE)
      {
         FileWriteString(fh, "==== SC EA start " + TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS) + " ====\n");
         FileClose(fh);
      }
   }

   EnsureHandles();
   BuildLoadReport();
   DbgPrint("init report\n" + g_debugReport);
   MaybePopupLoadError();

   EventSetTimer(1);
   RunEA(false);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   DeleteDebugWindow();
   ReleaseOurHandle();
   ReleaseDirect();
}

void OnTimer()
{
   bool newBar = IsNewBar();
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
   bool newBar = IsNewBar();
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
