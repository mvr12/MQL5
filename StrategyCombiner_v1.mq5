//+------------------------------------------------------------------+
//| StrategyCombiner_v1.mq5                                          |
//| 2 Custom Slots + Trend Confirmation + N-Bar Outcome              |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window
#property indicator_plots   5
#property indicator_buffers 5

#property indicator_label1  "BUY"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLime
#property indicator_width1  3

#property indicator_label2  "SELL"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_width2  3

#property indicator_label3  "Success"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  C'0,255,210'
#property indicator_width3  5

#property indicator_label4  "Failure"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  C'255,70,20'
#property indicator_width4  5

#property indicator_label5  "Trend Line"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrDodgerBlue
#property indicator_style5  STYLE_SOLID
#property indicator_width5  2


//==================================================================
//  ENUMS
//==================================================================
enum ENUM_TREND_COMPARE
{
   TREND_CMP_CLOSE  = 0,  // Close کندل اصلی
   TREND_CMP_OPEN   = 1,  // Open کندل اصلی
   TREND_CMP_HIGH   = 2,  // High کندل اصلی
   TREND_CMP_LOW    = 3,  // Low کندل اصلی
   TREND_CMP_SIGNAL = 4   // مقدار بافر سیگنال (میانگین منابع فعال)
};

enum ENUM_TREND_SIDE
{
   TREND_BUY_ABOVE_SELL_BELOW = 0, // خرید بالای خط / فروش زیر خط
   TREND_BUY_BELOW_SELL_ABOVE = 1  // برعکس
};

enum ENUM_TREND_SOURCE
{
   TREND_SOURCE_MA     = 0, // Moving Average داخلی MT5 (همیشه در دسترس)
   TREND_SOURCE_CUSTOM = 1  // اندیکاتور سفارشی روند
};


//==================================================================
//  INDICATOR 1
//==================================================================
input group "=== Custom Indicator 1 ==="
input bool   UseIndicator1         = true;
input string Indicator1_Name       = "Market\\Dark Bands MT5";
input int    Indicator1_BuyBuffer  = 0;
input int    Indicator1_SellBuffer = 1;


//==================================================================
//  INDICATOR 2
//==================================================================
input group "=== Custom Indicator 2 ==="
input bool   UseIndicator2         = true;
input string Indicator2_Name       = "MySecondIndicator";
input int    Indicator2_BuyBuffer  = 0;
input int    Indicator2_SellBuffer = 1;


//==================================================================
//  TREND CONFIRMATION (FILTER ONLY — NOT OUTCOME)
//==================================================================
input group "=== Trend Confirmation ==="
input bool               UseTrendIndicator     = true;
input ENUM_TREND_SOURCE  TrendSource           = TREND_SOURCE_MA;
input int                TrendMA_Period        = 50;
input ENUM_MA_METHOD     TrendMA_Method        = MODE_EMA;
input ENUM_APPLIED_PRICE TrendMA_AppliedPrice  = PRICE_CLOSE;
input string             TrendIndicator_Name   = "Examples\\Custom Moving Average";
input int                TrendIndicator_Buffer = 0;
input ENUM_TREND_COMPARE TrendCompareWith      = TREND_CMP_CLOSE;
input ENUM_TREND_SIDE    TrendSideRule         = TREND_BUY_ABOVE_SELL_BELOW;


//==================================================================
//  COMBINED SIGNAL / OUTCOME
//==================================================================
input group "=== Combined Signal ==="
input int    BarsForward      = 2;     // N کندل بعد برای موفق/شکست
input bool   IgnoreZeroValues = true;  // صفر = بدون سیگنال


//==================================================================
//  TIME & DAY FILTER
//==================================================================
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
//  DISPLAY
//==================================================================
input group "=== Display ==="
input bool   ShowSignalArrows = true;
input bool   ShowResultArrows = true;
input bool   ShowTrendLine    = true;
input bool   ShowStatistics   = true;


//==================================================================
//  HANDLES / BUFFERS
//==================================================================
int Handle1    = INVALID_HANDLE;
int Handle2    = INVALID_HANDLE;
int HandleTrend = INVALID_HANDLE;

double BuySignalBuffer[];
double SellSignalBuffer[];
double SuccessBuffer[];
double FailureBuffer[];
double TrendLineBuffer[];

double Buffer1_Buy[];
double Buffer1_Sell[];
double Buffer2_Buy[];
double Buffer2_Sell[];
double BufferTrend[];

int CopiedTrend = 0;


//==================================================================
//  STATISTICS
//==================================================================
int TotalSignals       = 0;
int SuccessfulSignals  = 0;
int FailedSignals      = 0;
int CurrentWinStreak   = 0;
int CurrentLossStreak  = 0;
int MaxWinStreak       = 0;
int MaxLossStreak      = 0;
int FilteredByTrend    = 0;


//==================================================================
//  DAY / TIME
//==================================================================
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

bool PassesDayFilter(const datetime t)
{
   if(!UseDayFilter)
      return true;
   return IsAllowedDay(t);
}

bool PassesHourFilter(const datetime t)
{
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

bool IsAllowedTime(const datetime t)
{
   return (PassesDayFilter(t) && PassesHourFilter(t));
}


//==================================================================
//  VALUE CHECKS
//==================================================================
bool IsSignalValue(const double value)
{
   if(value == EMPTY_VALUE || value == DBL_MAX)
      return false;
   if(!MathIsValidNumber(value))
      return false;
   if(IgnoreZeroValues && value == 0.0)
      return false;
   return true;
}

bool IsValidTrendValue(const double value)
{
   if(value == EMPTY_VALUE || value == DBL_MAX)
      return false;
   if(!MathIsValidNumber(value))
      return false;
   return true;
}


//==================================================================
//  SOURCE SIGNAL FROM ENABLED CUSTOM SLOTS
//  - هر دو روشن: AND
//  - فقط یکی روشن: سیگنال تکی همان اسلات
//==================================================================
int GetSourceSignal(const int shift, const int max_copied)
{
   if(shift < 0 || shift >= max_copied)
      return 0;

   if(!UseIndicator1 && !UseIndicator2)
      return 0;

   bool wantBuy  = true;
   bool wantSell = true;

   if(UseIndicator1)
   {
      bool i1Buy  = IsSignalValue(Buffer1_Buy[shift]);
      bool i1Sell = IsSignalValue(Buffer1_Sell[shift]);
      if(!i1Buy)  wantBuy  = false;
      if(!i1Sell) wantSell = false;
   }

   if(UseIndicator2)
   {
      bool i2Buy  = IsSignalValue(Buffer2_Buy[shift]);
      bool i2Sell = IsSignalValue(Buffer2_Sell[shift]);
      if(!i2Buy)  wantBuy  = false;
      if(!i2Sell) wantSell = false;
   }

   if(wantBuy && !wantSell)
      return 1;
   if(wantSell && !wantBuy)
      return -1;
   if(wantBuy)
      return 1;
   if(wantSell)
      return -1;
   return 0;
}


//==================================================================
//  COMPARE PRICE VS TREND LINE
//==================================================================
double GetCompareValue(
   const int shift,
   const int signal,
   const double &open[],
   const double &high[],
   const double &low[],
   const double &close[]
)
{
   if(TrendCompareWith == TREND_CMP_OPEN)
      return open[shift];
   if(TrendCompareWith == TREND_CMP_HIGH)
      return high[shift];
   if(TrendCompareWith == TREND_CMP_LOW)
      return low[shift];

   if(TrendCompareWith == TREND_CMP_SIGNAL)
   {
      double sum = 0.0;
      int    n   = 0;

      if(signal == 1)
      {
         if(UseIndicator1 && IsSignalValue(Buffer1_Buy[shift]))
         {
            sum += Buffer1_Buy[shift];
            n++;
         }
         if(UseIndicator2 && IsSignalValue(Buffer2_Buy[shift]))
         {
            sum += Buffer2_Buy[shift];
            n++;
         }
      }
      else if(signal == -1)
      {
         if(UseIndicator1 && IsSignalValue(Buffer1_Sell[shift]))
         {
            sum += Buffer1_Sell[shift];
            n++;
         }
         if(UseIndicator2 && IsSignalValue(Buffer2_Sell[shift]))
         {
            sum += Buffer2_Sell[shift];
            n++;
         }
      }

      if(n > 0)
         return sum / n;
   }

   return close[shift];
}

bool IsTrendConfirmed(
   const int signal,
   const int shift,
   const double &open[],
   const double &high[],
   const double &low[],
   const double &close[]
)
{
   if(!UseTrendIndicator)
      return true;

   if(shift < 0 || shift >= CopiedTrend)
      return false;

   double trend = BufferTrend[shift];
   if(!IsValidTrendValue(trend))
      return false;

   double ref = GetCompareValue(shift, signal, open, high, low, close);

   bool above = (ref > trend);
   bool below = (ref < trend);

   if(TrendSideRule == TREND_BUY_ABOVE_SELL_BELOW)
   {
      if(signal == 1)  return above;
      if(signal == -1) return below;
   }
   else
   {
      if(signal == 1)  return below;
      if(signal == -1) return above;
   }
   return false;
}

int GetFinalSignal(
   const int shift,
   const int max_copied,
   const double &open[],
   const double &high[],
   const double &low[],
   const double &close[]
)
{
   int signal = GetSourceSignal(shift, max_copied);
   if(signal == 0)
      return 0;

   if(!IsTrendConfirmed(signal, shift, open, high, low, close))
      return 0;

   return signal;
}


//==================================================================
//  STATISTICS HELPERS
//==================================================================
void RegisterResult(const bool success)
{
   TotalSignals++;

   if(success)
   {
      SuccessfulSignals++;
      CurrentWinStreak++;
      CurrentLossStreak = 0;
      if(CurrentWinStreak > MaxWinStreak)
         MaxWinStreak = CurrentWinStreak;
   }
   else
   {
      FailedSignals++;
      CurrentLossStreak++;
      CurrentWinStreak = 0;
      if(CurrentLossStreak > MaxLossStreak)
         MaxLossStreak = CurrentLossStreak;
   }
}

void CalculateStatistics(
   const int rates_total,
   const datetime &time[],
   const double &open[],
   const double &high[],
   const double &low[],
   const double &close[],
   const int max_copied
)
{
   TotalSignals      = 0;
   SuccessfulSignals = 0;
   FailedSignals     = 0;
   CurrentWinStreak  = 0;
   CurrentLossStreak = 0;
   MaxWinStreak      = 0;
   MaxLossStreak     = 0;
   FilteredByTrend   = 0;

   int oldestShift        = MathMin(rates_total - 1, max_copied - 1);
   int newestAllowedShift = BarsForward + 1;

   for(int shift = oldestShift; shift >= newestAllowedShift; shift--)
   {
      if(!IsAllowedTime(time[shift]))
         continue;

      int source = GetSourceSignal(shift, max_copied);
      if(source == 0)
         continue;

      if(!IsTrendConfirmed(source, shift, open, high, low, close))
      {
         FilteredByTrend++;
         continue;
      }

      int futureShift = shift - BarsForward;
      if(futureShift < 1)
         continue;

      bool success = false;
      if(source == 1)
         success = (close[futureShift] > close[shift]);
      else if(source == -1)
         success = (close[futureShift] < close[shift]);

      RegisterResult(success);
   }
}


//==================================================================
//  DRAW
//==================================================================
void DrawTrendLine(const int rates_total, const int max_copied)
{
   ArrayInitialize(TrendLineBuffer, EMPTY_VALUE);

   if(!UseTrendIndicator || !ShowTrendLine)
      return;

   int oldest = MathMin(MathMin(rates_total - 1, max_copied - 1), CopiedTrend - 1);
   for(int shift = oldest; shift >= 0; shift--)
   {
      if(IsValidTrendValue(BufferTrend[shift]))
         TrendLineBuffer[shift] = BufferTrend[shift];
   }
}

void DrawSignals(
   const int rates_total,
   const datetime &time[],
   const double &open[],
   const double &high[],
   const double &low[],
   const double &close[],
   const int max_copied
)
{
   ArrayInitialize(BuySignalBuffer,  EMPTY_VALUE);
   ArrayInitialize(SellSignalBuffer, EMPTY_VALUE);
   ArrayInitialize(SuccessBuffer,    EMPTY_VALUE);
   ArrayInitialize(FailureBuffer,    EMPTY_VALUE);

   DrawTrendLine(rates_total, max_copied);

   if(!ShowSignalArrows && !ShowResultArrows)
      return;

   int oldestShift        = MathMin(rates_total - 1, max_copied - 1);
   int newestAllowedShift = 1;

   for(int shift = oldestShift; shift >= newestAllowedShift; shift--)
   {
      if(!IsAllowedTime(time[shift]))
         continue;

      int signal = GetFinalSignal(shift, max_copied, open, high, low, close);
      if(signal == 0)
         continue;

      int futureShift = shift - BarsForward;

      if(signal == 1)
      {
         if(ShowSignalArrows)
            BuySignalBuffer[shift] = low[shift] - 12 * _Point;

         if(ShowResultArrows && futureShift >= 1)
         {
            bool success = (close[futureShift] > close[shift]);
            if(success)
               SuccessBuffer[shift] = low[shift] - 38 * _Point;
            else
               FailureBuffer[shift] = low[shift] - 38 * _Point;
         }
      }
      else if(signal == -1)
      {
         if(ShowSignalArrows)
            SellSignalBuffer[shift] = high[shift] + 12 * _Point;

         if(ShowResultArrows && futureShift >= 1)
         {
            bool success = (close[futureShift] < close[shift]);
            if(success)
               SuccessBuffer[shift] = high[shift] + 38 * _Point;
            else
               FailureBuffer[shift] = high[shift] + 38 * _Point;
         }
      }
   }
}


//==================================================================
//  PANEL
//==================================================================
string SlotState(const bool enabled)
{
   return enabled ? "ON" : "OFF";
}

string CompareModeText()
{
   if(TrendCompareWith == TREND_CMP_OPEN)   return "OPEN";
   if(TrendCompareWith == TREND_CMP_HIGH)   return "HIGH";
   if(TrendCompareWith == TREND_CMP_LOW)    return "LOW";
   if(TrendCompareWith == TREND_CMP_SIGNAL) return "SIGNAL VALUE";
   return "CLOSE";
}

void ShowStats()
{
   if(!ShowStatistics)
   {
      Comment("");
      return;
   }

   double successRate = 0.0;
   if(TotalSignals > 0)
      successRate = 100.0 * (double)SuccessfulSignals / (double)TotalSignals;

   string currentStreakText = "0";
   if(CurrentWinStreak > 0)
      currentStreakText = "+" + IntegerToString(CurrentWinStreak) + " (SUCCESS)";
   else if(CurrentLossStreak > 0)
      currentStreakText = "-" + IntegerToString(CurrentLossStreak) + " (FAILURE)";

   string dayFilterStatus = UseDayFilter ? "ENABLED" : "DISABLED";
   string timeFilterStatus = "DISABLED";
   if(UseTimeFilter)
   {
      timeFilterStatus = StringFormat("ENABLED (%02d:%02d - %02d:%02d)",
                                      StartHour, StartMinute, EndHour, EndMinute);
   }

   string trendSourceText = "MA";
   if(TrendSource == TREND_SOURCE_CUSTOM)
      trendSourceText = TrendIndicator_Name;
   else
      trendSourceText = StringFormat("EMA/MA(%d)", TrendMA_Period);

   string logicText = "NONE";
   if(UseIndicator1 && UseIndicator2)
      logicText = "AND (both customs)";
   else if(UseIndicator1)
      logicText = "SINGLE (Indicator 1)";
   else if(UseIndicator2)
      logicText = "SINGLE (Indicator 2)";

   string text =
      "========================================\n" +
      "   STRATEGY COMBINER v1.1\n" +
      "========================================\n" +
      "Ind 1 [" + SlotState(UseIndicator1) + "] : " + Indicator1_Name + "\n" +
      "Ind 2 [" + SlotState(UseIndicator2) + "] : " + Indicator2_Name + "\n" +
      "Trend [" + SlotState(UseTrendIndicator) + "] : " + trendSourceText + "\n" +
      "Trend role  : CONFIRM / FILTER only\n" +
      "Compare     : " + CompareModeText() + " vs trend line\n" +
      "Logic       : " + logicText + "\n" +
      "Outcome     : N-Bar Close (" + IntegerToString(BarsForward) + ")\n" +
      "Day Filter  : " + dayFilterStatus + "\n" +
      "Time Filter : " + timeFilterStatus + "\n" +
      "----------------------------------------\n" +
      "TOTAL SIGNALS       : " + IntegerToString(TotalSignals) + "\n" +
      "SUCCESSFUL SIGNALS  : " + IntegerToString(SuccessfulSignals) + "\n" +
      "FAILED SIGNALS      : " + IntegerToString(FailedSignals) + "\n" +
      "FILTERED BY TREND   : " + IntegerToString(FilteredByTrend) + "\n" +
      "SUCCESS RATE        : " + DoubleToString(successRate, 2) + "%\n" +
      "----------------------------------------\n" +
      "MAX SUCCESS STREAK  : " + IntegerToString(MaxWinStreak) + "\n" +
      "MAX FAILURE STREAK  : " + IntegerToString(MaxLossStreak) + "\n" +
      "CURRENT STREAK      : " + currentStreakText + "\n" +
      "========================================";

   Comment(text);
}


//==================================================================
//  INIT / DEINIT
//==================================================================
int OnInit()
{
   if(!UseIndicator1 && !UseIndicator2)
   {
      Print("ERROR: Enable at least one custom indicator slot.");
      return INIT_FAILED;
   }

   if(UseIndicator1)
   {
      Handle1 = iCustom(_Symbol, _Period, Indicator1_Name);
      if(Handle1 == INVALID_HANDLE)
      {
         Print("ERROR: Cannot load Indicator 1: ", Indicator1_Name, " | Error code: ", GetLastError());
         return INIT_FAILED;
      }
   }

   if(UseIndicator2)
   {
      Handle2 = iCustom(_Symbol, _Period, Indicator2_Name);
      if(Handle2 == INVALID_HANDLE)
      {
         Print("ERROR: Cannot load Indicator 2: ", Indicator2_Name, " | Error code: ", GetLastError());
         return INIT_FAILED;
      }
   }

   if(UseTrendIndicator)
   {
      if(TrendSource == TREND_SOURCE_MA)
      {
         if(TrendMA_Period < 1)
         {
            Print("ERROR: TrendMA_Period must be >= 1");
            return INIT_FAILED;
         }
         HandleTrend = iMA(_Symbol, _Period, TrendMA_Period, 0, TrendMA_Method, TrendMA_AppliedPrice);
      }
      else
      {
         HandleTrend = iCustom(_Symbol, _Period, TrendIndicator_Name);
      }

      if(HandleTrend == INVALID_HANDLE)
      {
         Print("ERROR: Cannot load Trend source | Error code: ", GetLastError());
         return INIT_FAILED;
      }
   }

   SetIndexBuffer(0, BuySignalBuffer,  INDICATOR_DATA);
   SetIndexBuffer(1, SellSignalBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, SuccessBuffer,    INDICATOR_DATA);
   SetIndexBuffer(3, FailureBuffer,    INDICATOR_DATA);
   SetIndexBuffer(4, TrendLineBuffer,  INDICATOR_DATA);

   ArraySetAsSeries(BuySignalBuffer,  true);
   ArraySetAsSeries(SellSignalBuffer, true);
   ArraySetAsSeries(SuccessBuffer,    true);
   ArraySetAsSeries(FailureBuffer,    true);
   ArraySetAsSeries(TrendLineBuffer,  true);

   PlotIndexSetInteger(0, PLOT_ARROW, 233); // hollow-ish up arrow (signal)
   PlotIndexSetInteger(1, PLOT_ARROW, 234); // hollow-ish down arrow (signal)
   PlotIndexSetInteger(2, PLOT_ARROW, 159); // filled circle  — SUCCESS
   PlotIndexSetInteger(3, PLOT_ARROW, 164); // filled square  — FAILURE

   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, 5);
   PlotIndexSetInteger(3, PLOT_LINE_WIDTH, 5);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   IndicatorSetString(INDICATOR_SHORTNAME, "Strategy Combiner v1.1");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(Handle1 != INVALID_HANDLE)
      IndicatorRelease(Handle1);
   if(Handle2 != INVALID_HANDLE)
      IndicatorRelease(Handle2);
   if(HandleTrend != INVALID_HANDLE)
      IndicatorRelease(HandleTrend);
   Comment("");
}


//==================================================================
//  CALCULATE
//==================================================================
int OnCalculate(
   const int rates_total,
   const int prev_calculated,
   const datetime &time[],
   const double &open[],
   const double &high[],
   const double &low[],
   const double &close[],
   const long &tick_volume[],
   const long &volume[],
   const int &spread[]
)
{
   if(rates_total < BarsForward + 10)
      return 0;

   ArraySetAsSeries(time,  true);
   ArraySetAsSeries(open,  true);
   ArraySetAsSeries(high,  true);
   ArraySetAsSeries(low,   true);
   ArraySetAsSeries(close, true);

   if(UseIndicator1 && BarsCalculated(Handle1) <= BarsForward)
      return prev_calculated;
   if(UseIndicator2 && BarsCalculated(Handle2) <= BarsForward)
      return prev_calculated;
   if(UseTrendIndicator && BarsCalculated(HandleTrend) <= BarsForward)
      return prev_calculated;

   ArraySetAsSeries(Buffer1_Buy,  true);
   ArraySetAsSeries(Buffer1_Sell, true);
   ArraySetAsSeries(Buffer2_Buy,  true);
   ArraySetAsSeries(Buffer2_Sell, true);
   ArraySetAsSeries(BufferTrend,  true);

   int max_copied = rates_total;

   if(UseIndicator1)
   {
      int cBuy  = CopyBuffer(Handle1, Indicator1_BuyBuffer,  0, rates_total, Buffer1_Buy);
      int cSell = CopyBuffer(Handle1, Indicator1_SellBuffer, 0, rates_total, Buffer1_Sell);
      if(cBuy <= BarsForward || cSell <= BarsForward)
         return prev_calculated;
      max_copied = MathMin(max_copied, MathMin(cBuy, cSell));
   }
   else
   {
      ArrayResize(Buffer1_Buy,  rates_total);
      ArrayResize(Buffer1_Sell, rates_total);
      ArrayInitialize(Buffer1_Buy,  EMPTY_VALUE);
      ArrayInitialize(Buffer1_Sell, EMPTY_VALUE);
   }

   if(UseIndicator2)
   {
      int cBuy  = CopyBuffer(Handle2, Indicator2_BuyBuffer,  0, rates_total, Buffer2_Buy);
      int cSell = CopyBuffer(Handle2, Indicator2_SellBuffer, 0, rates_total, Buffer2_Sell);
      if(cBuy <= BarsForward || cSell <= BarsForward)
         return prev_calculated;
      max_copied = MathMin(max_copied, MathMin(cBuy, cSell));
   }
   else
   {
      ArrayResize(Buffer2_Buy,  rates_total);
      ArrayResize(Buffer2_Sell, rates_total);
      ArrayInitialize(Buffer2_Buy,  EMPTY_VALUE);
      ArrayInitialize(Buffer2_Sell, EMPTY_VALUE);
   }

   CopiedTrend = 0;
   if(UseTrendIndicator)
   {
      int trendBuf = (TrendSource == TREND_SOURCE_MA) ? 0 : TrendIndicator_Buffer;
      CopiedTrend = CopyBuffer(HandleTrend, trendBuf, 0, rates_total, BufferTrend);
      if(CopiedTrend <= BarsForward)
         return prev_calculated;
      max_copied = MathMin(max_copied, CopiedTrend);
   }

   CalculateStatistics(rates_total, time, open, high, low, close, max_copied);
   DrawSignals(rates_total, time, open, high, low, close, max_copied);
   ShowStats();

   return rates_total;
}
//+------------------------------------------------------------------+
