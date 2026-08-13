//+------------------------------------------------------------------+
//| StrategyCombiner_EA_v1.mq5                                       |
//| Auto-trader driven by StrategyCombiner_v1 buffers                |
//| Does not modify the indicator file.                              |
//+------------------------------------------------------------------+
#property strict
#property copyright "Strategy Combiner"
#property version   "1.00"

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
input bool           UseIndicator2         = true;
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


//==================================================================
//  EA TRADE SETTINGS
//==================================================================
input group "=== Auto Trade ==="
input bool         AllowBuy           = true;
input bool         AllowSell          = true;
input bool         CloseOpposite      = true;
input bool         OnePositionOnly    = true;
input bool         TradeOnlyNewBar    = true;
input int          MaxSpreadPoints    = 40;
input ulong        MagicNumber        = 20260814;
input int          SlippagePoints     = 20;
input string       TradeComment       = "SC_EA_v1";

input group "=== Money Management ==="
input ENUM_LOT_MODE LotMode           = LOT_FIXED;
input double        FixedLot          = 0.10;
input double        RiskPercent       = 1.0;   // if LOT_RISK_PERCENT and SL > 0
input int           StopLossPoints    = 300;   // 0 = no SL
input int           TakeProfitPoints  = 600;   // 0 = no TP

input group "=== Combiner File ==="
input string        CombinerName      = "StrategyCombiner_v1";


CTrade   trade;
int      g_handle = INVALID_HANDLE;
datetime g_lastBar = 0;
datetime g_lastSignalBar = 0;


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

int CombinerHandle()
{
   // Display flags: arrows ON so BUY/SELL buffers are filled.
   // Other visuals OFF so the hidden iCustom instance does not spam objects.
   return iCustom(
      _Symbol,
      _Period,
      CombinerName,
      UseIndicator1,
      Indicator1_Mode,
      Indicator1_Name,
      Indicator1_BuyBuffer,
      Indicator1_SellBuffer,
      UseIndicator2,
      Indicator2_Mode,
      Indicator2_Name,
      Indicator2_BuyBuffer,
      Indicator2_SellBuffer,
      UseTrendIndicator,
      UseTrendLineFilter,
      TrendSource,
      TrendMA_Period,
      TrendMA_Method,
      TrendMA_AppliedPrice,
      TrendIndicator_Name,
      TrendIndicator_Buffer,
      TrendCompareWith,
      TrendSideRule,
      UseTrendAngleFilter,
      TrendAnglePeriod,
      AngleBuyFrom,
      AngleBuyTo,
      AngleSellFrom,
      AngleSellTo,
      UseTrendLineCross,
      TrendCrossRole,
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
      UNIT_PIPS,
      8,
      clrNONE,
      clrNONE
   );
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

int CurrentSignal()
{
   if(g_handle == INVALID_HANDLE)
      return 0;
   if(BarsCalculated(g_handle) < BarsForward + 5)
      return 0;

   double buy[2], sell[2];
   ArraySetAsSeries(buy, true);
   ArraySetAsSeries(sell, true);

   if(CopyBuffer(g_handle, 0, 0, 2, buy) < 2)
      return 0;
   if(CopyBuffer(g_handle, 1, 0, 2, sell) < 2)
      return 0;

   // shift 1 = last closed candle (same as indicator arrows)
   const bool buySig  = IsSignalValue(buy[1]);
   const bool sellSig = IsSignalValue(sell[1]);

   if(buySig && !sellSig)
      return 1;
   if(sellSig && !buySig)
      return -1;
   return 0;
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

double NormalizeLot(double lot)
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0)
      step = 0.01;
   lot = MathFloor(lot / step) * step;
   if(lot < minLot)
      lot = minLot;
   if(lot > maxLot)
      lot = maxLot;
   return NormalizeDouble(lot, 2);
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

bool OpenTrade(const int signal)
{
   if(signal == 1 && !AllowBuy)
      return false;
   if(signal == -1 && !AllowSell)
      return false;
   if(!SpreadOk())
   {
      Print("EA: spread too high");
      return false;
   }

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   double sl = 0.0, tp = 0.0;
   if(signal == 1)
   {
      if(StopLossPoints > 0)
         sl = NormalizeDouble(ask - StopLossPoints * point, digits);
      if(TakeProfitPoints > 0)
         tp = NormalizeDouble(ask + TakeProfitPoints * point, digits);
      double lot = CalcLot(sl, true);
      if(!trade.Buy(lot, _Symbol, ask, sl, tp, TradeComment))
      {
         Print("EA BUY failed: ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
         return false;
      }
      Print("EA BUY lot=", lot, " sl=", sl, " tp=", tp);
      return true;
   }

   if(StopLossPoints > 0)
      sl = NormalizeDouble(bid + StopLossPoints * point, digits);
   if(TakeProfitPoints > 0)
      tp = NormalizeDouble(bid - TakeProfitPoints * point, digits);
   double lot = CalcLot(sl, false);
   if(!trade.Sell(lot, _Symbol, bid, sl, tp, TradeComment))
   {
      Print("EA SELL failed: ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
      return false;
   }
   Print("EA SELL lot=", lot, " sl=", sl, " tp=", tp);
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
      return;

   if(OpenTrade(signal))
      g_lastSignalBar = closedBar;
}

int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(SlippagePoints);
   trade.SetTypeFillingBySymbol(_Symbol);

   g_handle = CombinerHandle();
   if(g_handle == INVALID_HANDLE)
   {
      Print("ERROR: Cannot load ", CombinerName,
            " — compile Indicators/StrategyCombiner_v1.mq5 first. Err=", GetLastError());
      return INIT_FAILED;
   }

   g_lastBar = iTime(_Symbol, _Period, 0);
   Print("StrategyCombiner EA ready. Combiner=", CombinerName);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_handle != INVALID_HANDLE)
      IndicatorRelease(g_handle);
}

void OnTick()
{
   if(TradeOnlyNewBar && !IsNewBar())
      return;

   ProcessSignal(CurrentSignal());
}
//+------------------------------------------------------------------+
