//+------------------------------------------------------------------+
//| StrategyCombiner_v1.mq5                                          |
//| 2 Custom Indicators + AND Logic + N-Bar Outcome Statistics      |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window
#property indicator_plots   4
#property indicator_buffers 4

#property indicator_label1  "Combined BUY"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLime
#property indicator_width1  2

#property indicator_label2  "Combined SELL"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_width2  2

#property indicator_label3  "Success"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrAqua
#property indicator_width3  1

#property indicator_label4  "Failure"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrOrange
#property indicator_width4  1


//==================================================================
//  INDICATOR 1 INPUTS
//==================================================================
input group "=== Custom Indicator 1 ==="
input string Indicator1_Name       = "Market\\Dark Bands MT5";
input int    Indicator1_BuyBuffer  = 0;
input int    Indicator1_SellBuffer = 1;


//==================================================================
//  INDICATOR 2 INPUTS
//==================================================================
input group "=== Custom Indicator 2 ==="
input string Indicator2_Name       = "MySecondIndicator";
input int    Indicator2_BuyBuffer  = 0;
input int    Indicator2_SellBuffer = 1;


//==================================================================
//  COMBINED SIGNAL SETTINGS
//==================================================================
input group "=== Combined Signal ==="
input int    BarsForward      = 2;     // تعداد کندل‌های بعد برای بررسی موفقیت/شکست
input bool   IgnoreZeroValues = true;  // اگر true باشد مقدار صفر سیگنال محسوب نمی‌شود


//==================================================================
//  TIME & DAY FILTER
//==================================================================
input group "=== Trading Days ==="
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
//  DISPLAY SETTINGS
//==================================================================
input group "=== Display ==="
input bool   ShowSignalArrows = true;
input bool   ShowResultArrows = true;
input bool   ShowStatistics   = true;


//==================================================================
//  HANDLES
//==================================================================
int Handle1 = INVALID_HANDLE;
int Handle2 = INVALID_HANDLE;


//==================================================================
//  OUTPUT BUFFERS
//==================================================================
double BuySignalBuffer[];
double SellSignalBuffer[];
double SuccessBuffer[];
double FailureBuffer[];


//==================================================================
//  DYNAMIC ARRAYS FOR OPTIMIZED BULK BUFFER COPYING
//==================================================================
double Buffer1_Buy[];
double Buffer1_Sell[];
double Buffer2_Buy[];
double Buffer2_Sell[];


//==================================================================
//  STATISTICS VARIABLES
//==================================================================
int TotalSignals       = 0;
int SuccessfulSignals  = 0;
int FailedSignals      = 0;

int CurrentWinStreak   = 0;
int CurrentLossStreak  = 0;

int MaxWinStreak       = 0;
int MaxLossStreak      = 0;


//==================================================================
//  CHECK ALLOWED DAY OF WEEK
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


//==================================================================
//  CHECK ALLOWED TIME RANGE
//==================================================================
bool IsAllowedTime(const datetime t)
{
   if(!UseTimeFilter)
      return true;

   if(!IsAllowedDay(t))
      return false;

   MqlDateTime dt;
   TimeToStruct(t, dt);

   int currentMinutes = dt.hour * 60 + dt.min;
   int startMinutes   = StartHour * 60 + StartMinute;
   int endMinutes     = EndHour * 60 + EndMinute;

   // بازه زمانی معمولی در طول یک روز
   if(startMinutes <= endMinutes)
   {
      return (currentMinutes >= startMinutes && currentMinutes <= endMinutes);
   }

   // بازه عبوری از نیمه‌شب (مثلاً 22:00 تا 02:00)
   return (currentMinutes >= startMinutes || currentMinutes <= endMinutes);
}


//==================================================================
//  CHECK SIGNAL BUFFER VALUE VALIDITY
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


//==================================================================
//  GET COMBINED SIGNAL (OPTIMIZED USING COPIED BUFFERS)
//
//  1  = BUY  (هر دو اندیکاتور سیگنال خرید می‌دهند)
// -1  = SELL (هر دو اندیکاتور سیگنال فروش می‌دهند)
//  0  = NONE / INVALID
//==================================================================
int GetCombinedSignal(const int shift, const int max_copied)
{
   if(shift < 0 || shift >= max_copied)
      return 0;

   double i1Buy  = Buffer1_Buy[shift];
   double i1Sell = Buffer1_Sell[shift];
   double i2Buy  = Buffer2_Buy[shift];
   double i2Sell = Buffer2_Sell[shift];

   bool ind1Buy  = IsSignalValue(i1Buy);
   bool ind1Sell = IsSignalValue(i1Sell);
   bool ind2Buy  = IsSignalValue(i2Buy);
   bool ind2Sell = IsSignalValue(i2Sell);

   //===============================================================
   // AND Logic: BUY
   //===============================================================
   if(ind1Buy && ind2Buy && !ind1Sell && !ind2Sell)
      return 1;

   //===============================================================
   // AND Logic: SELL
   //===============================================================
   if(ind1Sell && ind2Sell && !ind1Buy && !ind2Buy)
      return -1;

   // Fallback در صورتی که بافرهای خرید و فروش هم‌پوشانی داشته باشند
   if(ind1Buy && ind2Buy)
      return 1;

   if(ind1Sell && ind2Sell)
      return -1;

   return 0;
}


//==================================================================
//  REGISTER RESULT IN STATISTICS
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


//==================================================================
//  CALCULATE HISTORICAL STATISTICS OVER N-BAR OUTCOME
//==================================================================
void CalculateStatistics(
   const int rates_total,
   const datetime &time[],
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

   //===============================================================
   // در MQL5 بعد از فراخوانی ArraySetAsSeries:
   // shift 0 = کندل جاری (در حال تشکیل)
   // shift 1 = آخرین کندل بسته شده
   //
   // برای سیگنال در کندل shift = S
   // قیمت بسته شدن N کندل بعد برابر است با:
   // futureShift = S - BarsForward
   //
   // بنابراین جدیدترین کندلی که نتیجه آن قطعی شده:
   // newestAllowedShift = BarsForward + 1
   //===============================================================

   int oldestShift        = MathMin(rates_total - 1, max_copied - 1);
   int newestAllowedShift = BarsForward + 1;

   // از قدیمی‌ترین کندل به جدیدترین حرکت می‌کنیم تا Streak دقیق محاسبه شود
   for(int shift = oldestShift; shift >= newestAllowedShift; shift--)
   {
      datetime signalTime = time[shift];

      if(!IsAllowedTime(signalTime))
         continue;

      int signal = GetCombinedSignal(shift, max_copied);

      if(signal == 0)
         continue;

      int futureShift = shift - BarsForward;

      if(futureShift < 1)
         continue;

      double signalClose = close[shift];
      double futureClose = close[futureShift];

      bool success = false;

      //============================================================
      // BUY: موفقیت یعنی Close در N کندل بعد بالاتر از Close سیگنال
      //============================================================
      if(signal == 1)
      {
         if(futureClose > signalClose)
            success = true;
      }
      //============================================================
      // SELL: موفقیت یعنی Close در N کندل بعد پایین‌تر از Close سیگنال
      //============================================================
      else if(signal == -1)
      {
         if(futureClose < signalClose)
            success = true;
      }

      RegisterResult(success);
   }
}


//==================================================================
//  DRAW SIGNALS AND OUTCOME ARROWS
//==================================================================
void DrawSignals(
   const int rates_total,
   const datetime &time[],
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

   if(!ShowSignalArrows && !ShowResultArrows)
      return;

   int oldestShift        = MathMin(rates_total - 1, max_copied - 1);
   int newestAllowedShift = 1; // نمایش فلش سیگنال برای تمام کندل‌های بسته‌شده

   for(int shift = oldestShift; shift >= newestAllowedShift; shift--)
   {
      if(!IsAllowedTime(time[shift]))
         continue;

      int signal = GetCombinedSignal(shift, max_copied);

      if(signal == 0)
         continue;

      int futureShift = shift - BarsForward;

      //============================================================
      // BUY SIGNAL & RESULT
      //============================================================
      if(signal == 1)
      {
         if(ShowSignalArrows)
            BuySignalBuffer[shift] = low[shift] - 10 * _Point;

         // نمایش نتیجه موفقیت/شکست روی کندل سیگنال (فقط اگر کندل آینده بسته شده باشد)
         if(ShowResultArrows && futureShift >= 1)
         {
            bool success = (close[futureShift] > close[shift]);

            if(success)
               SuccessBuffer[shift] = low[shift] - 25 * _Point;
            else
               FailureBuffer[shift] = low[shift] - 25 * _Point;
         }
      }
      //============================================================
      // SELL SIGNAL & RESULT
      //============================================================
      else if(signal == -1)
      {
         if(ShowSignalArrows)
            SellSignalBuffer[shift] = high[shift] + 10 * _Point;

         if(ShowResultArrows && futureShift >= 1)
         {
            bool success = (close[futureShift] < close[shift]);

            if(success)
               SuccessBuffer[shift] = high[shift] + 25 * _Point;
            else
               FailureBuffer[shift] = high[shift] + 25 * _Point;
         }
      }
   }
}


//==================================================================
//  STATISTICS PANEL DISPLAY
//==================================================================
void ShowStats()
{
   if(!ShowStatistics)
   {
      Comment("");
      return;
   }

   double successRate = 0.0;
   if(TotalSignals > 0)
   {
      successRate = 100.0 * (double)SuccessfulSignals / (double)TotalSignals;
   }

   string currentStreakText = "0";
   if(CurrentWinStreak > 0)
      currentStreakText = "+" + IntegerToString(CurrentWinStreak) + " (SUCCESS)";
   else if(CurrentLossStreak > 0)
      currentStreakText = "-" + IntegerToString(CurrentLossStreak) + " (FAILURE)";

   string timeFilterStatus = "DISABLED";
   if(UseTimeFilter)
   {
      timeFilterStatus = StringFormat("ENABLED (%02d:%02d - %02d:%02d)",
                                      StartHour, StartMinute, EndHour, EndMinute);
   }

   string text =
      "========================================\n" +
      "   STRATEGY COMBINER v1 (Custom Ind.)\n" +
      "========================================\n" +
      "Indicator 1 : " + Indicator1_Name + "\n" +
      "BUY Buffer  : " + IntegerToString(Indicator1_BuyBuffer) +
      " | SELL Buffer: " + IntegerToString(Indicator1_SellBuffer) + "\n\n" +

      "Indicator 2 : " + Indicator2_Name + "\n" +
      "BUY Buffer  : " + IntegerToString(Indicator2_BuyBuffer) +
      " | SELL Buffer: " + IntegerToString(Indicator2_SellBuffer) + "\n\n" +

      "Logic Mode  : AND\n" +
      "Outcome Bars: " + IntegerToString(BarsForward) + " (N-Bar Close)\n" +
      "Time Filter : " + timeFilterStatus + "\n" +
      "----------------------------------------\n" +
      "TOTAL SIGNALS       : " + IntegerToString(TotalSignals) + "\n" +
      "SUCCESSFUL SIGNALS  : " + IntegerToString(SuccessfulSignals) + "\n" +
      "FAILED SIGNALS      : " + IntegerToString(FailedSignals) + "\n" +
      "SUCCESS RATE        : " + DoubleToString(successRate, 2) + "%\n" +
      "----------------------------------------\n" +
      "MAX SUCCESS STREAK  : " + IntegerToString(MaxWinStreak) + "\n" +
      "MAX FAILURE STREAK  : " + IntegerToString(MaxLossStreak) + "\n" +
      "CURRENT STREAK      : " + currentStreakText + "\n" +
      "========================================";

   Comment(text);
}


//==================================================================
//  INIT
//==================================================================
int OnInit()
{
   //===============================================================
   // Create Indicator 1 Handle
   //===============================================================
   Handle1 = iCustom(_Symbol, _Period, Indicator1_Name);
   if(Handle1 == INVALID_HANDLE)
   {
      Print("ERROR: Cannot load Indicator 1: ", Indicator1_Name, " | Error code: ", GetLastError());
      return INIT_FAILED;
   }

   //===============================================================
   // Create Indicator 2 Handle
   //===============================================================
   Handle2 = iCustom(_Symbol, _Period, Indicator2_Name);
   if(Handle2 == INVALID_HANDLE)
   {
      Print("ERROR: Cannot load Indicator 2: ", Indicator2_Name, " | Error code: ", GetLastError());
      return INIT_FAILED;
   }

   //===============================================================
   // Bind output indicator buffers
   //===============================================================
   SetIndexBuffer(0, BuySignalBuffer,  INDICATOR_DATA);
   SetIndexBuffer(1, SellSignalBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, SuccessBuffer,    INDICATOR_DATA);
   SetIndexBuffer(3, FailureBuffer,    INDICATOR_DATA);

   ArraySetAsSeries(BuySignalBuffer,  true);
   ArraySetAsSeries(SellSignalBuffer, true);
   ArraySetAsSeries(SuccessBuffer,    true);
   ArraySetAsSeries(FailureBuffer,    true);

   PlotIndexSetInteger(0, PLOT_ARROW, 233); // Up Arrow
   PlotIndexSetInteger(1, PLOT_ARROW, 234); // Down Arrow
   PlotIndexSetInteger(2, PLOT_ARROW, 241); // Checkmark (Success)
   PlotIndexSetInteger(3, PLOT_ARROW, 242); // Cross (Failure)

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   IndicatorSetString(INDICATOR_SHORTNAME, "Strategy Combiner v1");

   return INIT_SUCCEEDED;
}


//==================================================================
//  DEINIT
//==================================================================
void OnDeinit(const int reason)
{
   if(Handle1 != INVALID_HANDLE)
      IndicatorRelease(Handle1);

   if(Handle2 != INVALID_HANDLE)
      IndicatorRelease(Handle2);

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

   //===============================================================
   // تنظیم آرایه‌های قیمت به صورت سری زمانی (shift 0 = کندل جاری)
   //===============================================================
   ArraySetAsSeries(time,  true);
   ArraySetAsSeries(open,  true);
   ArraySetAsSeries(high,  true);
   ArraySetAsSeries(low,   true);
   ArraySetAsSeries(close, true);

   // بررسی آماده بودن داده‌های اندیکاتورهای خارجی
   int barsReady1 = BarsCalculated(Handle1);
   int barsReady2 = BarsCalculated(Handle2);

   if(barsReady1 <= BarsForward || barsReady2 <= BarsForward)
      return prev_calculated;

   //===============================================================
   // کپی کلی بافرها برای بالاترین راندمان محاسباتی (بدون کپی تک‌به‌تک در حلقه)
   //===============================================================
   ArraySetAsSeries(Buffer1_Buy,  true);
   ArraySetAsSeries(Buffer1_Sell, true);
   ArraySetAsSeries(Buffer2_Buy,  true);
   ArraySetAsSeries(Buffer2_Sell, true);

   int copied1_buy  = CopyBuffer(Handle1, Indicator1_BuyBuffer,  0, rates_total, Buffer1_Buy);
   int copied1_sell = CopyBuffer(Handle1, Indicator1_SellBuffer, 0, rates_total, Buffer1_Sell);
   int copied2_buy  = CopyBuffer(Handle2, Indicator2_BuyBuffer,  0, rates_total, Buffer2_Buy);
   int copied2_sell = CopyBuffer(Handle2, Indicator2_SellBuffer, 0, rates_total, Buffer2_Sell);

   if(copied1_buy <= BarsForward || copied1_sell <= BarsForward ||
      copied2_buy <= BarsForward || copied2_sell <= BarsForward)
   {
      return prev_calculated;
   }

   int max_copied = MathMin(MathMin(copied1_buy, copied1_sell), MathMin(copied2_buy, copied2_sell));
   max_copied     = MathMin(max_copied, rates_total);

   // محاسبه آمار موفقیت و شکست بر اساس N کندل بعد
   CalculateStatistics(rates_total, time, close, max_copied);

   // رسم فلش‌های خرید/فروش و علائم موفقیت/شکست
   DrawSignals(rates_total, time, high, low, close, max_copied);

   // نمایش پنل آماری روی چارت
   ShowStats();

   return rates_total;
}
//+------------------------------------------------------------------+
