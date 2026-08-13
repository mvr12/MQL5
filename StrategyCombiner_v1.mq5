//+------------------------------------------------------------------+
//| StrategyCombiner_v1.mq5                                          |
//| Slots + Cross + Trend Angle + N-Bar Pips                         |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window
#property indicator_plots   6
#property indicator_buffers 6

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


#property indicator_label6  "Trend Line 2"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrOrange
#property indicator_style6  STYLE_SOLID
#property indicator_width6  2


//==================================================================
//  ENUMS
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
   SLOT_MODE_BUFFERS      = 0, // بافر خرید / فروش
   SLOT_MODE_CROSS_SIGNAL = 1, // کراس دو بافر همان اندیکاتور = خرید/فروش
   SLOT_MODE_CROSS_TREND  = 2  // موقعیت دو بافر همان اندیکاتور = فیلتر روند
};

enum ENUM_TREND_CROSS_ROLE
{
   TREND_CROSS_SIGNAL    = 0,
   TREND_CROSS_NEW_TREND = 1
};

enum ENUM_PROFIT_UNIT
{
   UNIT_PIPS   = 0, // پیپ
   UNIT_POINTS = 1  // پوینت
};


//==================================================================
//  INDICATOR 1
//==================================================================
input group "=== Custom Indicator 1 ==="
input bool           UseIndicator1         = true;
input ENUM_SLOT_MODE Indicator1_Mode       = SLOT_MODE_BUFFERS;
input string         Indicator1_Name       = "Market\\Dark Bands MT5";
input int            Indicator1_BuyBuffer  = 0; // یا Fast / Buffer A
input int            Indicator1_SellBuffer = 1; // یا Slow / Buffer B


//==================================================================
//  INDICATOR 2
//==================================================================
input group "=== Custom Indicator 2 ==="
input bool           UseIndicator2         = true;
input ENUM_SLOT_MODE Indicator2_Mode       = SLOT_MODE_BUFFERS;
input string         Indicator2_Name       = "MySecondIndicator";
input int            Indicator2_BuyBuffer  = 0;
input int            Indicator2_SellBuffer = 1;


//==================================================================
//  TREND LINE + ANGLE
//==================================================================
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


//==================================================================
//  COUNT / OUTCOME / PIPS
//==================================================================
input group "=== Count & Outcome ==="
input int    StatsLookbackBars = 1000; // چند کندل اخیر آمار گرفته شود؛ 0 = همه
input int    BarsForward       = 2;    // N کندل بعد برای موفق/شکست و پیپ
input bool   IgnoreZeroValues  = true;


//==================================================================
//  TIME & DAY
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
input bool             ShowSignalArrows = true;
input bool             ShowResultArrows = true;
input bool             ShowTrendLine    = true;
input bool             ShowStatistics   = true;
input bool             ShowPipLabels    = true;
input int              MaxPipLabels     = 80;
input bool             ShowCandleTimer  = true;
input color            TimerColor       = C'0,230,180';
input int              TimerFontSize    = 11;
input int              TimerX           = 12;
input int              TimerY           = 18;
input ENUM_PROFIT_UNIT ProfitUnit       = UNIT_PIPS;
input int              PipLabelFontSize = 9;
input color            ProfitLabelColor = C'0,230,180';
input color            LossLabelColor   = C'255,80,40';


//==================================================================
//  HANDLES / BUFFERS
//==================================================================
int Handle1     = INVALID_HANDLE;
int Handle2     = INVALID_HANDLE;
int HandleTrend = INVALID_HANDLE;

double BuySignalBuffer[];
double SellSignalBuffer[];
double SuccessBuffer[];
double FailureBuffer[];
double TrendLineBuffer[];
double TrendLine2Buffer[];

double Buffer1_Buy[];
double Buffer1_Sell[];
double Buffer2_Buy[];
double Buffer2_Sell[];
double BufferTrend[];
double Buffer1_Trend[];
double Buffer2_Trend[];

int CopiedTrend  = 0;
int Copied1      = 0;
int Copied2      = 0;
int CopiedTrend1 = 0;
int CopiedTrend2 = 0;


//==================================================================
//  STATISTICS
//==================================================================
int    TotalSignals      = 0;
int    SuccessfulSignals = 0;
int    FailedSignals     = 0;
int    CurrentWinStreak  = 0;
int    CurrentLossStreak = 0;
int    MaxWinStreak      = 0;
int    MaxLossStreak     = 0;
int    FilteredByTrend   = 0;
double TotalPips         = 0.0;
double AveragePips       = 0.0;
int    CountedBarsWindow = 0;
bool   g_busy            = false;


int Px(const int rates_total, const int shift)
{
   return rates_total - 1 - shift;
}


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
//  VALUE / PIP HELPERS
//==================================================================
bool IsFiniteNumber(const double value)
{
   if(value == EMPTY_VALUE || value == DBL_MAX)
      return false;
   return MathIsValidNumber(value);
}

bool IsSignalValue(const double value)
{
   if(!IsFiniteNumber(value))
      return false;
   if(IgnoreZeroValues && value == 0.0)
      return false;
   return true;
}

bool IsValidTrendValue(const double value)
{
   return IsFiniteNumber(value);
}

double PipSize()
{
   if(_Point <= 0.0)
      return 1.0;
   if(_Digits == 3 || _Digits == 5)
      return _Point * 10.0;
   return _Point;
}

double CalcPips(const int signal, const double signalClose, const double futureClose)
{
   double raw = (signal == 1) ? (futureClose - signalClose) : (signalClose - futureClose);
   return raw / PipSize();
}

double CalcPoints(const int signal, const double signalClose, const double futureClose)
{
   double raw = (signal == 1) ? (futureClose - signalClose) : (signalClose - futureClose);
   if(_Point <= 0.0)
      return raw;
   return raw / _Point;
}

double CalcDisplayProfit(const int signal, const double signalClose, const double futureClose)
{
   if(ProfitUnit == UNIT_POINTS)
      return CalcPoints(signal, signalClose, futureClose);
   return CalcPips(signal, signalClose, futureClose);
}

string ProfitUnitText()
{
   return (ProfitUnit == UNIT_POINTS) ? "pt" : "pip";
}

#define SC_PL_PREFIX "SC_PL_"

void DeletePipLabels()
{
   ObjectsDeleteAll(0, SC_PL_PREFIX);
}

void DrawPipLabel(const datetime barTime, const double price, const double value)
{
   string name = SC_PL_PREFIX + IntegerToString((long)barTime);
   string text = StringFormat("%+.1f %s", value, ProfitUnitText());
   color  clr  = (value > 0.0) ? ProfitLabelColor : ((value < 0.0) ? LossLabelColor : clrSilver);

   if(ObjectFind(0, name) < 0)
   {
      if(!ObjectCreate(0, name, OBJ_TEXT, 0, barTime, price))
         return;
   }

   ObjectSetInteger(0, name, OBJPROP_TIME, barTime);
   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, PipLabelFontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
}

bool SlotIsSignalSource(const bool used, const ENUM_SLOT_MODE mode)
{
   return used && (mode == SLOT_MODE_BUFFERS || mode == SLOT_MODE_CROSS_SIGNAL);
}

bool SlotIsTrendSource(const bool used, const ENUM_SLOT_MODE mode)
{
   return used && mode == SLOT_MODE_CROSS_TREND;
}


//==================================================================
//  CROSS HELPERS
//==================================================================
bool IsCrossUp(const double &fast[], const double &slow[], const int shift, const int copied)
{
   if(shift < 0 || shift + 1 >= copied)
      return false;
   double f0 = fast[shift];
   double s0 = slow[shift];
   double f1 = fast[shift + 1];
   double s1 = slow[shift + 1];
   if(!IsFiniteNumber(f0) || !IsFiniteNumber(s0) || !IsFiniteNumber(f1) || !IsFiniteNumber(s1))
      return false;
   return (f1 <= s1 && f0 > s0);
}

bool IsCrossDown(const double &fast[], const double &slow[], const int shift, const int copied)
{
   if(shift < 0 || shift + 1 >= copied)
      return false;
   double f0 = fast[shift];
   double s0 = slow[shift];
   double f1 = fast[shift + 1];
   double s1 = slow[shift + 1];
   if(!IsFiniteNumber(f0) || !IsFiniteNumber(s0) || !IsFiniteNumber(f1) || !IsFiniteNumber(s1))
      return false;
   return (f1 >= s1 && f0 < s0);
}

int CrossPosition(const double &fast[], const double &slow[], const int shift, const int copied)
{
   if(shift < 0 || shift >= copied)
      return 0;
   if(!IsFiniteNumber(fast[shift]) || !IsFiniteNumber(slow[shift]))
      return 0;
   if(fast[shift] > slow[shift])
      return 1;
   if(fast[shift] < slow[shift])
      return -1;
   return 0;
}

int GetSlotSignal(
   const bool used,
   const ENUM_SLOT_MODE mode,
   const double &fast[],
   const double &slow[],
   const int shift,
   const int copied
)
{
   if(!used || shift < 0 || shift >= copied)
      return 0;

   if(mode == SLOT_MODE_CROSS_TREND)
      return 0;

   if(mode == SLOT_MODE_CROSS_SIGNAL)
   {
      if(IsCrossUp(fast, slow, shift, copied))
         return 1;
      if(IsCrossDown(fast, slow, shift, copied))
         return -1;
      return 0;
   }

   bool buy  = IsSignalValue(fast[shift]);
   bool sell = IsSignalValue(slow[shift]);
   if(buy && !sell)
      return 1;
   if(sell && !buy)
      return -1;
   if(buy && sell)
      return 1;
   return 0;
}


//==================================================================
//  SOURCE SIGNAL (AND among signal-source slots)
//==================================================================
int GetSourceSignal(const int shift, const int max_copied)
{
   if(shift < 0 || shift >= max_copied)
      return 0;

   bool hasSignalSlot = false;
   bool wantBuy  = true;
   bool wantSell = true;

   if(SlotIsSignalSource(UseIndicator1, Indicator1_Mode))
   {
      hasSignalSlot = true;
      int dir = GetSlotSignal(true, Indicator1_Mode, Buffer1_Buy, Buffer1_Sell, shift, Copied1);
      if(dir != 1)  wantBuy  = false;
      if(dir != -1) wantSell = false;
   }

   if(SlotIsSignalSource(UseIndicator2, Indicator2_Mode))
   {
      hasSignalSlot = true;
      int dir = GetSlotSignal(true, Indicator2_Mode, Buffer2_Buy, Buffer2_Sell, shift, Copied2);
      if(dir != 1)  wantBuy  = false;
      if(dir != -1) wantSell = false;
   }

   if(UseTrendLineCross && TrendCrossRole == TREND_CROSS_SIGNAL)
   {
      hasSignalSlot = true;
      int dir = 0;
      int copied = MathMin(CopiedTrend1, CopiedTrend2);
      if(IsCrossUp(Buffer1_Trend, Buffer2_Trend, shift, copied))
         dir = 1;
      else if(IsCrossDown(Buffer1_Trend, Buffer2_Trend, shift, copied))
         dir = -1;
      if(dir != 1)  wantBuy  = false;
      if(dir != -1) wantSell = false;
   }

   if(!hasSignalSlot)
      return 0;
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
//  TREND LINE COMPARE
//==================================================================
double GetCompareValue(
   const int rates_total,
   const int shift,
   const int signal,
   const double &open[],
   const double &high[],
   const double &low[],
   const double &close[]
)
{
   const int i = Px(rates_total, shift);
   if(TrendCompareWith == TREND_CMP_OPEN)
      return open[i];
   if(TrendCompareWith == TREND_CMP_HIGH)
      return high[i];
   if(TrendCompareWith == TREND_CMP_LOW)
      return low[i];

   if(TrendCompareWith == TREND_CMP_SIGNAL)
   {
      double sum = 0.0;
      int    n   = 0;
      if(signal == 1)
      {
         if(UseIndicator1 && IsSignalValue(Buffer1_Buy[shift])) { sum += Buffer1_Buy[shift]; n++; }
         if(UseIndicator2 && IsSignalValue(Buffer2_Buy[shift])) { sum += Buffer2_Buy[shift]; n++; }
      }
      else if(signal == -1)
      {
         if(UseIndicator1 && IsSignalValue(Buffer1_Sell[shift])) { sum += Buffer1_Sell[shift]; n++; }
         if(UseIndicator2 && IsSignalValue(Buffer2_Sell[shift])) { sum += Buffer2_Sell[shift]; n++; }
      }
      if(n > 0)
         return sum / n;
   }
   return close[i];
}

bool IsTrendLineConfirmed(
   const int rates_total,
   const int signal,
   const int shift,
   const double &open[],
   const double &high[],
   const double &low[],
   const double &close[]
)
{
   if(!UseTrendIndicator || !UseTrendLineFilter)
      return true;
   if(shift < 0 || shift >= CopiedTrend)
      return false;
   if(!IsValidTrendValue(BufferTrend[shift]))
      return false;

   double ref = GetCompareValue(rates_total, shift, signal, open, high, low, close);
   bool above = (ref > BufferTrend[shift]);
   bool below = (ref < BufferTrend[shift]);

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

bool IsCrossTrendConfirmed(const int signal, const int shift)
{
   if(SlotIsTrendSource(UseIndicator1, Indicator1_Mode))
   {
      int pos = CrossPosition(Buffer1_Buy, Buffer1_Sell, shift, Copied1);
      if(pos == 0 || pos != signal)
         return false;
   }
   if(SlotIsTrendSource(UseIndicator2, Indicator2_Mode))
   {
      int pos = CrossPosition(Buffer2_Buy, Buffer2_Sell, shift, Copied2);
      if(pos == 0 || pos != signal)
         return false;
   }
   return true;
}

double GetTrendAngle(const int shift)
{
   if(TrendAnglePeriod < 1)
      return 0.0;
   int older = shift + TrendAnglePeriod;
   if(older >= CopiedTrend)
      return 0.0;
   if(!IsValidTrendValue(BufferTrend[shift]) || !IsValidTrendValue(BufferTrend[older]))
      return 0.0;

   double dy = BufferTrend[shift] - BufferTrend[older];
   double dx = TrendAnglePeriod * PipSize();
   if(dx == 0.0)
      return 0.0;
   return MathArctan(dy / dx) * 180.0 / M_PI;
}

bool InRange(const double value, const double from, const double to)
{
   double lo = MathMin(from, to);
   double hi = MathMax(from, to);
   return (value >= lo && value <= hi);
}

int GetTrendAngleState(const int shift)
{
   double angle = GetTrendAngle(shift);
   if(InRange(angle, AngleBuyFrom, AngleBuyTo))
      return 1;
   if(InRange(angle, AngleSellFrom, AngleSellTo))
      return -1;
   return 0;
}

bool IsTwoTrendCrossConfirmed(const int signal, const int shift)
{
   if(!UseTrendLineCross || TrendCrossRole != TREND_CROSS_NEW_TREND)
      return true;
   int copied = MathMin(CopiedTrend1, CopiedTrend2);
   int pos = CrossPosition(Buffer1_Trend, Buffer2_Trend, shift, copied);
   return (pos != 0 && pos == signal);
}

bool IsTrendAngleConfirmed(const int signal, const int shift)
{
   if(!UseTrendAngleFilter)
      return true;
   if(!UseTrendIndicator)
      return false;
   return (GetTrendAngleState(shift) == signal);
}

bool IsTrendConfirmed(
   const int rates_total,
   const int signal,
   const int shift,
   const double &open[],
   const double &high[],
   const double &low[],
   const double &close[]
)
{
   if(!IsTrendLineConfirmed(rates_total, signal, shift, open, high, low, close))
      return false;
   if(!IsCrossTrendConfirmed(signal, shift))
      return false;
   if(!IsTrendAngleConfirmed(signal, shift))
      return false;
   if(!IsTwoTrendCrossConfirmed(signal, shift))
      return false;
   return true;
}

int GetFinalSignal(
   const int rates_total,
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
   if(!IsTrendConfirmed(rates_total, signal, shift, open, high, low, close))
      return 0;
   return signal;
}


//==================================================================
//  STATISTICS
//==================================================================
void RegisterResult(const bool success, const double pips)
{
   TotalSignals++;
   TotalPips += pips;

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
   TotalPips         = 0.0;
   AveragePips       = 0.0;

   int newestAllowedShift = BarsForward + 1;
   int oldestShift        = MathMin(rates_total - 1, max_copied - 1);
   if(StatsLookbackBars > 0)
      oldestShift = MathMin(oldestShift, newestAllowedShift + StatsLookbackBars - 1);

   CountedBarsWindow = MathMax(0, oldestShift - newestAllowedShift + 1);

   for(int shift = oldestShift; shift >= newestAllowedShift; shift--)
   {
      const int i = Px(rates_total, shift);
      if(!IsAllowedTime(time[i]))
         continue;

      int source = GetSourceSignal(shift, max_copied);
      if(source == 0)
         continue;

      if(!IsTrendConfirmed(rates_total, source, shift, open, high, low, close))
      {
         FilteredByTrend++;
         continue;
      }

      int futureShift = shift - BarsForward;
      if(futureShift < 1)
         continue;

      const int f = Px(rates_total, futureShift);
      bool success = false;
      if(source == 1)
         success = (close[f] > close[i]);
      else if(source == -1)
         success = (close[f] < close[i]);

      RegisterResult(success, CalcPips(source, close[i], close[f]));
   }

   if(TotalSignals > 0)
      AveragePips = TotalPips / (double)TotalSignals;
}


//==================================================================
//  DRAW
//==================================================================
void DrawTrendLine(const int rates_total, const int max_copied)
{
   ArrayInitialize(TrendLineBuffer, EMPTY_VALUE);
   ArrayInitialize(TrendLine2Buffer, EMPTY_VALUE);
   if(!ShowTrendLine)
      return;

   if(UseTrendLineCross)
   {
      int oldest = MathMin(MathMin(rates_total - 1, CopiedTrend1 - 1), CopiedTrend2 - 1);
      for(int shift = oldest; shift >= 0; shift--)
      {
         if(IsValidTrendValue(Buffer1_Trend[shift]))
            TrendLineBuffer[shift] = Buffer1_Trend[shift];
         if(IsValidTrendValue(Buffer2_Trend[shift]))
            TrendLine2Buffer[shift] = Buffer2_Trend[shift];
      }
      return;
   }

   if(!UseTrendIndicator)
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
   const int max_copied,
   const bool fullRedraw
)
{
   if(fullRedraw)
   {
      ArrayInitialize(BuySignalBuffer,  EMPTY_VALUE);
      ArrayInitialize(SellSignalBuffer, EMPTY_VALUE);
      ArrayInitialize(SuccessBuffer,    EMPTY_VALUE);
      ArrayInitialize(FailureBuffer,    EMPTY_VALUE);
      DrawTrendLine(rates_total, max_copied);
      if(ShowPipLabels)
         DeletePipLabels();
   }

   if(!ShowSignalArrows && !ShowResultArrows && !ShowPipLabels)
      return;

   int newestAllowedShift = 1;
   int oldestShift        = MathMin(rates_total - 1, max_copied - 1);
   if(StatsLookbackBars > 0)
      oldestShift = MathMin(oldestShift, newestAllowedShift + StatsLookbackBars - 1);
   if(!fullRedraw)
      oldestShift = MathMin(oldestShift, 5);

   const int maxLabels = (MaxPipLabels < 1) ? 80 : MaxPipLabels;

   for(int shift = oldestShift; shift >= newestAllowedShift; shift--)
   {
      const int i = Px(rates_total, shift);
      if(!IsAllowedTime(time[i]))
         continue;

      int signal = GetFinalSignal(rates_total, shift, max_copied, open, high, low, close);
      if(signal == 0)
         continue;

      int futureShift = shift - BarsForward;
      if(signal == 1)
      {
         if(ShowSignalArrows)
            BuySignalBuffer[shift] = low[i] - 12 * _Point;
         if(futureShift >= 1)
         {
            const int f = Px(rates_total, futureShift);
            double pnl = CalcDisplayProfit(1, close[i], close[f]);
            if(ShowResultArrows)
            {
               if(close[f] > close[i])
                  SuccessBuffer[shift] = low[i] - 38 * _Point;
               else
                  FailureBuffer[shift] = low[i] - 38 * _Point;
            }
            if(ShowPipLabels && shift <= maxLabels)
               DrawPipLabel(time[i], low[i] - 58 * _Point, pnl);
         }
      }
      else if(signal == -1)
      {
         if(ShowSignalArrows)
            SellSignalBuffer[shift] = high[i] + 12 * _Point;
         if(futureShift >= 1)
         {
            const int f = Px(rates_total, futureShift);
            double pnl = CalcDisplayProfit(-1, close[i], close[f]);
            if(ShowResultArrows)
            {
               if(close[f] < close[i])
                  SuccessBuffer[shift] = high[i] + 38 * _Point;
               else
                  FailureBuffer[shift] = high[i] + 38 * _Point;
            }
            if(ShowPipLabels && shift <= maxLabels)
               DrawPipLabel(time[i], high[i] + 58 * _Point, pnl);
         }
      }
   }
}


//==================================================================
//  PANEL
//==================================================================
string SlotState(const bool enabled) { return enabled ? "ON" : "OFF"; }

string SlotModeText(const ENUM_SLOT_MODE mode)
{
   if(mode == SLOT_MODE_CROSS_SIGNAL) return "CROSS SIGNAL";
   if(mode == SLOT_MODE_CROSS_TREND)  return "CROSS TREND";
   return "BUFFERS";
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
      timeFilterStatus = StringFormat("ENABLED (%02d:%02d - %02d:%02d)",
                                      StartHour, StartMinute, EndHour, EndMinute);

   string trendSourceText = StringFormat("MA(%d)", TrendMA_Period);
   if(TrendSource == TREND_SOURCE_CUSTOM)
      trendSourceText = TrendIndicator_Name;

   string lookbackText = (StatsLookbackBars > 0)
                         ? IntegerToString(StatsLookbackBars)
                         : "ALL";

   string text =
      "========================================\n" +
      "   STRATEGY COMBINER v1.2\n" +
      "========================================\n" +
      "Ind 1 [" + SlotState(UseIndicator1) + "] " + SlotModeText(Indicator1_Mode) + "\n" +
      "Ind 2 [" + SlotState(UseIndicator2) + "] " + SlotModeText(Indicator2_Mode) + "\n" +
      "Trend [" + SlotState(UseTrendIndicator) + "] " + trendSourceText + "\n" +
      "Line filter : " + (UseTrendLineFilter ? "ON" : "OFF") +
      " | Angle: " + (UseTrendAngleFilter ? "ON" : "OFF") + "\n" +
      "Angle ranges: BUY " + DoubleToString(AngleBuyFrom, 0) + ".." + DoubleToString(AngleBuyTo, 0) +
      " | SELL " + DoubleToString(AngleSellFrom, 0) + ".." + DoubleToString(AngleSellTo, 0) +
      " | else NEUTRAL\n" +
      "Trend cross : " + (UseTrendLineCross ? (TrendCrossRole == TREND_CROSS_SIGNAL ? "SIGNAL" : "NEW TREND") : "OFF") + "\n" +
      "Compare     : " + CompareModeText() + " vs line\n" +
      "Lookback    : last " + lookbackText + " bars (" + IntegerToString(CountedBarsWindow) + " scanned)\n" +
      "Outcome N   : " + IntegerToString(BarsForward) + " candles after signal\n" +
      "Day / Time  : " + dayFilterStatus + " / " + timeFilterStatus + "\n" +
      "----------------------------------------\n" +
      "TOTAL SIGNALS       : " + IntegerToString(TotalSignals) + "\n" +
      "SUCCESSFUL SIGNALS  : " + IntegerToString(SuccessfulSignals) + "\n" +
      "FAILED SIGNALS      : " + IntegerToString(FailedSignals) + "\n" +
      "FILTERED BY TREND   : " + IntegerToString(FilteredByTrend) + "\n" +
      "SUCCESS RATE        : " + DoubleToString(successRate, 2) + "%\n" +
      "TOTAL PIPS (N-bar)  : " + StringFormat("%+.2f", TotalPips) + "\n" +
      "AVERAGE PIPS        : " + StringFormat("%+.2f", AveragePips) + "\n" +
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
   bool hasSignal =
      SlotIsSignalSource(UseIndicator1, Indicator1_Mode) ||
      SlotIsSignalSource(UseIndicator2, Indicator2_Mode) ||
      (UseTrendLineCross && TrendCrossRole == TREND_CROSS_SIGNAL);

   if(!hasSignal)
   {
      Print("ERROR: Enable a signal source (slot BUFFERS/CROSS SIGNAL or two-trend-line cross).");
      return INIT_FAILED;
   }

   if(UseTrendLineCross && (!UseIndicator1 || !UseIndicator2))
   {
      Print("ERROR: Two-indicator trend cross needs both custom indicators enabled.");
      return INIT_FAILED;
   }

   if(BarsForward < 1)
   {
      Print("ERROR: BarsForward must be >= 1");
      return INIT_FAILED;
   }

   if(UseIndicator1)
   {
      Handle1 = iCustom(_Symbol, _Period, Indicator1_Name);
      if(Handle1 == INVALID_HANDLE)
      {
         Print("ERROR: Cannot load Indicator 1: ", Indicator1_Name, " | Error: ", GetLastError());
         return INIT_FAILED;
      }
   }

   if(UseIndicator2)
   {
      Handle2 = iCustom(_Symbol, _Period, Indicator2_Name);
      if(Handle2 == INVALID_HANDLE)
      {
         Print("ERROR: Cannot load Indicator 2: ", Indicator2_Name, " | Error: ", GetLastError());
         return INIT_FAILED;
      }
   }

   if(UseTrendIndicator || UseTrendAngleFilter)
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
         HandleTrend = iCustom(_Symbol, _Period, TrendIndicator_Name);

      if(HandleTrend == INVALID_HANDLE)
      {
         Print("ERROR: Cannot load Trend source | Error: ", GetLastError());
         return INIT_FAILED;
      }
   }

   SetIndexBuffer(0, BuySignalBuffer,  INDICATOR_DATA);
   SetIndexBuffer(1, SellSignalBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, SuccessBuffer,    INDICATOR_DATA);
   SetIndexBuffer(3, FailureBuffer,    INDICATOR_DATA);
   SetIndexBuffer(4, TrendLineBuffer,  INDICATOR_DATA);
   SetIndexBuffer(5, TrendLine2Buffer, INDICATOR_DATA);

   ArraySetAsSeries(BuySignalBuffer,  true);
   ArraySetAsSeries(SellSignalBuffer, true);
   ArraySetAsSeries(SuccessBuffer,    true);
   ArraySetAsSeries(FailureBuffer,    true);
   ArraySetAsSeries(TrendLineBuffer,  true);
   ArraySetAsSeries(TrendLine2Buffer, true);

   PlotIndexSetInteger(0, PLOT_ARROW, 233);
   PlotIndexSetInteger(1, PLOT_ARROW, 234);
   PlotIndexSetInteger(2, PLOT_ARROW, 159);
   PlotIndexSetInteger(3, PLOT_ARROW, 164);
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, 5);
   PlotIndexSetInteger(3, PLOT_LINE_WIDTH, 5);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(5, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   IndicatorSetString(INDICATOR_SHORTNAME, "Strategy Combiner v1.2");

   if(ShowCandleTimer)
   {
      EventSetTimer(1);
      UpdateCandleTimer();
   }
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
   DeletePipLabels();
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
   if(g_busy)
      return prev_calculated;
   g_busy = true;

   if(rates_total < BarsForward + 10)
   {
      g_busy = false;
      return 0;
   }

   if(UseIndicator1 && BarsCalculated(Handle1) <= BarsForward)
   {
      g_busy = false;
      return prev_calculated;
   }
   if(UseIndicator2 && BarsCalculated(Handle2) <= BarsForward)
   {
      g_busy = false;
      return prev_calculated;
   }
   if((UseTrendIndicator || UseTrendAngleFilter) && BarsCalculated(HandleTrend) <= BarsForward)
   {
      g_busy = false;
      return prev_calculated;
   }

   ArraySetAsSeries(Buffer1_Buy,  true);
   ArraySetAsSeries(Buffer1_Sell, true);
   ArraySetAsSeries(Buffer2_Buy,  true);
   ArraySetAsSeries(Buffer2_Sell, true);
   ArraySetAsSeries(BufferTrend,    true);
   ArraySetAsSeries(Buffer1_Trend,  true);
   ArraySetAsSeries(Buffer2_Trend,  true);

   int copyCount = rates_total;
   if(StatsLookbackBars > 0)
      copyCount = MathMin(rates_total, StatsLookbackBars + BarsForward + 30);

   int max_copied = copyCount;
   Copied1 = 0;
   Copied2 = 0;
   CopiedTrend = 0;

   if(UseIndicator1)
   {
      int cBuy  = CopyBuffer(Handle1, Indicator1_BuyBuffer,  0, copyCount, Buffer1_Buy);
      int cSell = CopyBuffer(Handle1, Indicator1_SellBuffer, 0, copyCount, Buffer1_Sell);
      if(cBuy <= BarsForward || cSell <= BarsForward)
      {
         g_busy = false;
         return prev_calculated;
      }
      Copied1 = MathMin(cBuy, cSell);
      max_copied = MathMin(max_copied, Copied1);
   }
   else
   {
      ArrayResize(Buffer1_Buy, copyCount);
      ArrayResize(Buffer1_Sell, copyCount);
      ArrayInitialize(Buffer1_Buy, EMPTY_VALUE);
      ArrayInitialize(Buffer1_Sell, EMPTY_VALUE);
      Copied1 = copyCount;
   }

   if(UseIndicator2)
   {
      int cBuy  = CopyBuffer(Handle2, Indicator2_BuyBuffer,  0, copyCount, Buffer2_Buy);
      int cSell = CopyBuffer(Handle2, Indicator2_SellBuffer, 0, copyCount, Buffer2_Sell);
      if(cBuy <= BarsForward || cSell <= BarsForward)
      {
         g_busy = false;
         return prev_calculated;
      }
      Copied2 = MathMin(cBuy, cSell);
      max_copied = MathMin(max_copied, Copied2);
   }
   else
   {
      ArrayResize(Buffer2_Buy, copyCount);
      ArrayResize(Buffer2_Sell, copyCount);
      ArrayInitialize(Buffer2_Buy, EMPTY_VALUE);
      ArrayInitialize(Buffer2_Sell, EMPTY_VALUE);
      Copied2 = copyCount;
   }

   if(UseTrendIndicator || UseTrendAngleFilter)
   {
      int trendBuf = (TrendSource == TREND_SOURCE_MA) ? 0 : TrendIndicator_Buffer;
      CopiedTrend = CopyBuffer(HandleTrend, trendBuf, 0, copyCount, BufferTrend);
      if(CopiedTrend <= BarsForward)
      {
         g_busy = false;
         return prev_calculated;
      }
      max_copied = MathMin(max_copied, CopiedTrend);
   }

   CopiedTrend1 = 0;
   CopiedTrend2 = 0;
   if(UseTrendLineCross)
   {
      CopiedTrend1 = CopyBuffer(Handle1, TrendLine1_Buffer, 0, copyCount, Buffer1_Trend);
      CopiedTrend2 = CopyBuffer(Handle2, TrendLine2_Buffer, 0, copyCount, Buffer2_Trend);
      if(CopiedTrend1 <= BarsForward || CopiedTrend2 <= BarsForward)
      {
         g_busy = false;
         return prev_calculated;
      }
      max_copied = MathMin(max_copied, MathMin(CopiedTrend1, CopiedTrend2));
   }

   const bool fullRedraw = (prev_calculated <= 0 || rates_total != prev_calculated);
   if(fullRedraw)
   {
      CalculateStatistics(rates_total, time, open, high, low, close, max_copied);
      DrawSignals(rates_total, time, open, high, low, close, max_copied, true);
      ShowStats();
   }
   else
      DrawSignals(rates_total, time, open, high, low, close, max_copied, false);

   g_busy = false;
   return rates_total;
}
//+------------------------------------------------------------------+
