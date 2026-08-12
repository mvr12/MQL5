"""
Pure-Python port of StrategyCombiner_v1.mq5 business logic (v1.1).

Indexing matches MQL5 after ArraySetAsSeries(..., true):
  shift 0 = current forming candle
  shift 1 = last closed candle
  larger shift = older candle

Trend line is a confirmation FILTER only.
Success / failure remains N-bar Close comparison.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from datetime import datetime
from typing import List, Optional, Sequence


EMPTY_VALUE = float("inf")
DBL_MAX = float("inf")

TREND_CMP_CLOSE = "close"
TREND_CMP_OPEN = "open"
TREND_CMP_HIGH = "high"
TREND_CMP_LOW = "low"
TREND_CMP_SIGNAL = "signal"


@dataclass
class CombinerConfig:
    bars_forward: int = 2
    ignore_zero_values: bool = True
    monday: bool = True
    tuesday: bool = True
    wednesday: bool = True
    thursday: bool = True
    friday: bool = True
    saturday: bool = False
    sunday: bool = False
    use_day_filter: bool = True
    use_time_filter: bool = True
    start_hour: int = 0
    start_minute: int = 0
    end_hour: int = 23
    end_minute: int = 59
    show_signal_arrows: bool = True
    show_result_arrows: bool = True
    use_indicator1: bool = True
    use_indicator2: bool = True
    use_trend: bool = False
    trend_compare: str = TREND_CMP_CLOSE
    buy_above_sell_below: bool = True


@dataclass
class Bar:
    time: datetime
    open: float
    high: float
    low: float
    close: float
    i1_buy: float = EMPTY_VALUE
    i1_sell: float = EMPTY_VALUE
    i2_buy: float = EMPTY_VALUE
    i2_sell: float = EMPTY_VALUE
    trend: float = EMPTY_VALUE


@dataclass
class SignalEvent:
    shift: int
    time: datetime
    direction: int
    signal_close: float
    future_shift: Optional[int]
    future_close: Optional[float]
    success: Optional[bool]
    counted_in_stats: bool
    filtered_by_trend: bool = False


@dataclass
class Statistics:
    total: int = 0
    successful: int = 0
    failed: int = 0
    current_win_streak: int = 0
    current_loss_streak: int = 0
    max_win_streak: int = 0
    max_loss_streak: int = 0
    filtered_by_trend: int = 0
    events: List[SignalEvent] = field(default_factory=list)

    @property
    def success_rate(self) -> float:
        if self.total <= 0:
            return 0.0
        return 100.0 * self.successful / self.total

    @property
    def current_streak_text(self) -> str:
        if self.current_win_streak > 0:
            return f"+{self.current_win_streak} (SUCCESS)"
        if self.current_loss_streak > 0:
            return f"-{self.current_loss_streak} (FAILURE)"
        return "0"


def is_signal_value(value: float, ignore_zero_values: bool) -> bool:
    if value == EMPTY_VALUE or value == DBL_MAX:
        return False
    if not math.isfinite(value):
        return False
    if ignore_zero_values and value == 0.0:
        return False
    return True


def is_valid_trend_value(value: float) -> bool:
    if value == EMPTY_VALUE or value == DBL_MAX:
        return False
    return math.isfinite(value)


def is_allowed_day(t: datetime, cfg: CombinerConfig) -> bool:
    mapping = {
        0: cfg.monday,
        1: cfg.tuesday,
        2: cfg.wednesday,
        3: cfg.thursday,
        4: cfg.friday,
        5: cfg.saturday,
        6: cfg.sunday,
    }
    return mapping[t.weekday()]


def is_allowed_time(t: datetime, cfg: CombinerConfig) -> bool:
    if cfg.use_day_filter and not is_allowed_day(t, cfg):
        return False
    if not cfg.use_time_filter:
        return True

    current_minutes = t.hour * 60 + t.minute
    start_minutes = cfg.start_hour * 60 + cfg.start_minute
    end_minutes = cfg.end_hour * 60 + cfg.end_minute

    if start_minutes <= end_minutes:
        return start_minutes <= current_minutes <= end_minutes
    return current_minutes >= start_minutes or current_minutes <= end_minutes


def get_source_signal(bar: Bar, cfg: CombinerConfig) -> int:
    if not cfg.use_indicator1 and not cfg.use_indicator2:
        return 0

    want_buy = True
    want_sell = True

    if cfg.use_indicator1:
        i1_buy = is_signal_value(bar.i1_buy, cfg.ignore_zero_values)
        i1_sell = is_signal_value(bar.i1_sell, cfg.ignore_zero_values)
        if not i1_buy:
            want_buy = False
        if not i1_sell:
            want_sell = False

    if cfg.use_indicator2:
        i2_buy = is_signal_value(bar.i2_buy, cfg.ignore_zero_values)
        i2_sell = is_signal_value(bar.i2_sell, cfg.ignore_zero_values)
        if not i2_buy:
            want_buy = False
        if not i2_sell:
            want_sell = False

    if want_buy and not want_sell:
        return 1
    if want_sell and not want_buy:
        return -1
    if want_buy:
        return 1
    if want_sell:
        return -1
    return 0


def get_combined_signal(bar: Bar, cfg: CombinerConfig) -> int:
    """Back-compat name: source signal without trend filter."""
    return get_source_signal(bar, cfg)


def get_compare_value(bar: Bar, signal: int, cfg: CombinerConfig) -> float:
    if cfg.trend_compare == TREND_CMP_OPEN:
        return bar.open
    if cfg.trend_compare == TREND_CMP_HIGH:
        return bar.high
    if cfg.trend_compare == TREND_CMP_LOW:
        return bar.low
    if cfg.trend_compare == TREND_CMP_SIGNAL:
        vals = []
        if signal == 1:
            if cfg.use_indicator1 and is_signal_value(bar.i1_buy, cfg.ignore_zero_values):
                vals.append(bar.i1_buy)
            if cfg.use_indicator2 and is_signal_value(bar.i2_buy, cfg.ignore_zero_values):
                vals.append(bar.i2_buy)
        elif signal == -1:
            if cfg.use_indicator1 and is_signal_value(bar.i1_sell, cfg.ignore_zero_values):
                vals.append(bar.i1_sell)
            if cfg.use_indicator2 and is_signal_value(bar.i2_sell, cfg.ignore_zero_values):
                vals.append(bar.i2_sell)
        if vals:
            return sum(vals) / len(vals)
    return bar.close


def is_trend_confirmed(bar: Bar, signal: int, cfg: CombinerConfig) -> bool:
    if not cfg.use_trend:
        return True
    if not is_valid_trend_value(bar.trend):
        return False

    ref = get_compare_value(bar, signal, cfg)
    above = ref > bar.trend
    below = ref < bar.trend

    if cfg.buy_above_sell_below:
        if signal == 1:
            return above
        if signal == -1:
            return below
    else:
        if signal == 1:
            return below
        if signal == -1:
            return above
    return False


def get_final_signal(bar: Bar, cfg: CombinerConfig) -> int:
    signal = get_source_signal(bar, cfg)
    if signal == 0:
        return 0
    if not is_trend_confirmed(bar, signal, cfg):
        return 0
    return signal


def register_result(stats: Statistics, success: bool) -> None:
    stats.total += 1
    if success:
        stats.successful += 1
        stats.current_win_streak += 1
        stats.current_loss_streak = 0
        if stats.current_win_streak > stats.max_win_streak:
            stats.max_win_streak = stats.current_win_streak
    else:
        stats.failed += 1
        stats.current_loss_streak += 1
        stats.current_win_streak = 0
        if stats.current_loss_streak > stats.max_loss_streak:
            stats.max_loss_streak = stats.current_loss_streak


def series_index(bars: Sequence[Bar], shift: int) -> Bar:
    return bars[-(shift + 1)]


def run_combiner(bars: Sequence[Bar], cfg: CombinerConfig) -> Statistics:
    stats = Statistics()
    rates_total = len(bars)
    if rates_total < cfg.bars_forward + 10:
        return stats

    oldest_shift = rates_total - 1
    newest_allowed_shift = cfg.bars_forward + 1

    for shift in range(oldest_shift, newest_allowed_shift - 1, -1):
        bar = series_index(bars, shift)
        if not is_allowed_time(bar.time, cfg):
            continue

        source = get_source_signal(bar, cfg)
        if source == 0:
            continue

        if not is_trend_confirmed(bar, source, cfg):
            stats.filtered_by_trend += 1
            continue

        future_shift = shift - cfg.bars_forward
        if future_shift < 1:
            continue

        future_bar = series_index(bars, future_shift)
        success = False
        if source == 1:
            success = future_bar.close > bar.close
        elif source == -1:
            success = future_bar.close < bar.close

        register_result(stats, success)
        stats.events.append(
            SignalEvent(
                shift=shift,
                time=bar.time,
                direction=source,
                signal_close=bar.close,
                future_shift=future_shift,
                future_close=future_bar.close,
                success=success,
                counted_in_stats=True,
            )
        )

    return stats


def collect_drawn_signals(bars: Sequence[Bar], cfg: CombinerConfig) -> List[SignalEvent]:
    drawn: List[SignalEvent] = []
    rates_total = len(bars)
    oldest_shift = rates_total - 1

    for shift in range(oldest_shift, 0, -1):
        bar = series_index(bars, shift)
        if not is_allowed_time(bar.time, cfg):
            continue
        signal = get_final_signal(bar, cfg)
        if signal == 0:
            continue

        future_shift = shift - cfg.bars_forward
        success = None
        future_close = None
        if future_shift >= 1:
            future_bar = series_index(bars, future_shift)
            future_close = future_bar.close
            if signal == 1:
                success = future_bar.close > bar.close
            else:
                success = future_bar.close < bar.close

        drawn.append(
            SignalEvent(
                shift=shift,
                time=bar.time,
                direction=signal,
                signal_close=bar.close,
                future_shift=future_shift if future_shift >= 1 else None,
                future_close=future_close,
                success=success,
                counted_in_stats=future_shift >= 1,
            )
        )
    return drawn
