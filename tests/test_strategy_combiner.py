"""
Acceptance tests for StrategyCombiner v1 expectations.

These tests do not compile MQL5. They verify the documented v1 rules
by running a line-by-line Python port of the indicator logic.
"""

from __future__ import annotations

import math
import unittest
from datetime import datetime, timedelta

from strategy_combiner_logic import (
    EMPTY_VALUE,
    TREND_CMP_HIGH,
    TREND_CMP_SIGNAL,
    Bar,
    CombinerConfig,
    collect_drawn_signals,
    get_combined_signal,
    get_final_signal,
    is_allowed_day,
    is_allowed_time,
    is_signal_value,
    run_combiner,
)


def bar(
    t: datetime,
    close: float,
    i1_buy=EMPTY_VALUE,
    i1_sell=EMPTY_VALUE,
    i2_buy=EMPTY_VALUE,
    i2_sell=EMPTY_VALUE,
    high=None,
    low=None,
    trend=EMPTY_VALUE,
) -> Bar:
    return Bar(
        time=t,
        open=close,
        high=close + 1 if high is None else high,
        low=close - 1 if low is None else low,
        close=close,
        i1_buy=i1_buy,
        i1_sell=i1_sell,
        i2_buy=i2_buy,
        i2_sell=i2_sell,
        trend=trend,
    )


def weekday(hour=10, minute=0, weekday=0, day=3) -> datetime:
    """Default: Monday 2026-08-03 10:00 (weekday 0 = Monday)."""
    # 2026-08-03 is Monday
    base = datetime(2026, 8, 3 + weekday, hour, minute)
    return base.replace(day=3 + weekday)


class SignalValueTests(unittest.TestCase):
    def test_empty_and_inf_are_not_signals(self):
        self.assertFalse(is_signal_value(EMPTY_VALUE, True))
        self.assertFalse(is_signal_value(float("inf"), True))
        self.assertFalse(is_signal_value(float("nan"), True))
        self.assertFalse(is_signal_value(float("-inf"), True))

    def test_zero_ignored_when_flag_true(self):
        self.assertFalse(is_signal_value(0.0, True))
        self.assertTrue(is_signal_value(0.0, False))

    def test_nonzero_price_is_signal(self):
        self.assertTrue(is_signal_value(1.2345, True))
        self.assertTrue(is_signal_value(-10.0, True))


class AndLogicTests(unittest.TestCase):
    def setUp(self):
        self.cfg = CombinerConfig()

    def test_both_buy_gives_buy(self):
        b = bar(weekday(), 100, i1_buy=1.0, i2_buy=1.0)
        self.assertEqual(get_combined_signal(b, self.cfg), 1)

    def test_both_sell_gives_sell(self):
        b = bar(weekday(), 100, i1_sell=1.0, i2_sell=1.0)
        self.assertEqual(get_combined_signal(b, self.cfg), -1)

    def test_only_indicator1_buy_is_no_signal(self):
        b = bar(weekday(), 100, i1_buy=1.0)
        self.assertEqual(get_combined_signal(b, self.cfg), 0)

    def test_only_indicator2_buy_is_no_signal(self):
        b = bar(weekday(), 100, i2_buy=1.0)
        self.assertEqual(get_combined_signal(b, self.cfg), 0)

    def test_only_one_sell_is_no_signal(self):
        b = bar(weekday(), 100, i1_sell=1.0)
        self.assertEqual(get_combined_signal(b, self.cfg), 0)

    def test_conflict_buy_vs_sell_is_no_signal(self):
        b = bar(weekday(), 100, i1_buy=1.0, i2_sell=1.0)
        self.assertEqual(get_combined_signal(b, self.cfg), 0)

    def test_zeros_do_not_count_as_buy_when_ignored(self):
        b = bar(weekday(), 100, i1_buy=0.0, i2_buy=0.0)
        self.assertEqual(get_combined_signal(b, self.cfg), 0)

    def test_zeros_count_when_ignore_flag_false(self):
        cfg = CombinerConfig(ignore_zero_values=False)
        b = bar(weekday(), 100, i1_buy=0.0, i2_buy=0.0)
        self.assertEqual(get_combined_signal(b, cfg), 1)

    def test_both_buy_and_both_sell_fallback_prefers_buy(self):
        # Current MQL fallback: if both buy (even with sells) return BUY first
        b = bar(weekday(), 100, i1_buy=1.0, i1_sell=1.0, i2_buy=1.0, i2_sell=1.0)
        self.assertEqual(get_combined_signal(b, self.cfg), 1)


class TimeFilterTests(unittest.TestCase):
    def test_weekend_rejected_when_filter_on(self):
        cfg = CombinerConfig(use_time_filter=True, saturday=False, sunday=False)
        saturday = datetime(2026, 8, 8, 10, 0)  # Saturday
        sunday = datetime(2026, 8, 9, 10, 0)
        monday = datetime(2026, 8, 3, 10, 0)
        self.assertFalse(is_allowed_time(saturday, cfg))
        self.assertFalse(is_allowed_time(sunday, cfg))
        self.assertTrue(is_allowed_time(monday, cfg))

    def test_hours_outside_window_rejected(self):
        cfg = CombinerConfig(
            use_time_filter=True,
            start_hour=9,
            start_minute=0,
            end_hour=17,
            end_minute=0,
        )
        self.assertFalse(is_allowed_time(datetime(2026, 8, 3, 8, 59), cfg))
        self.assertTrue(is_allowed_time(datetime(2026, 8, 3, 9, 0), cfg))
        self.assertTrue(is_allowed_time(datetime(2026, 8, 3, 17, 0), cfg))
        self.assertFalse(is_allowed_time(datetime(2026, 8, 3, 17, 1), cfg))

    def test_overnight_session(self):
        cfg = CombinerConfig(
            use_time_filter=True,
            start_hour=22,
            start_minute=0,
            end_hour=2,
            end_minute=0,
        )
        self.assertTrue(is_allowed_time(datetime(2026, 8, 3, 22, 0), cfg))
        self.assertTrue(is_allowed_time(datetime(2026, 8, 3, 23, 30), cfg))
        self.assertTrue(is_allowed_time(datetime(2026, 8, 3, 1, 0), cfg))
        self.assertTrue(is_allowed_time(datetime(2026, 8, 3, 2, 0), cfg))
        self.assertFalse(is_allowed_time(datetime(2026, 8, 3, 2, 1), cfg))
        self.assertFalse(is_allowed_time(datetime(2026, 8, 3, 12, 0), cfg))

    def test_day_filter_works_even_when_hour_filter_is_off(self):
        cfg = CombinerConfig(use_time_filter=False, use_day_filter=True, saturday=False, sunday=False)
        saturday = datetime(2026, 8, 8, 3, 0)
        monday = datetime(2026, 8, 3, 3, 0)
        self.assertFalse(is_allowed_time(saturday, cfg))
        self.assertTrue(is_allowed_time(monday, cfg))

    def test_day_filter_can_be_disabled_independently(self):
        cfg = CombinerConfig(use_time_filter=False, use_day_filter=False, saturday=False, sunday=False)
        saturday = datetime(2026, 8, 8, 3, 0)
        self.assertTrue(is_allowed_time(saturday, cfg))


class OutcomeAndStatsTests(unittest.TestCase):
    def _pad(self, events, start=datetime(2026, 8, 3, 0, 0)):
        """Build enough bars so rates_total >= BarsForward + 10."""
        bars = []
        t = start
        for i in range(30):
            bars.append(bar(t, 100.0 + i * 0.01))
            t += timedelta(hours=1)
        # overlay explicit events by timestamp
        by_time = {b.time: idx for idx, b in enumerate(bars)}
        for ev in events:
            idx = by_time[ev.time]
            bars[idx] = ev
        return bars

    def test_buy_success_when_future_close_higher(self):
        cfg = CombinerConfig(bars_forward=2)
        t0 = datetime(2026, 8, 3, 10, 0)
        bars = []
        t = datetime(2026, 8, 3, 0, 0)
        for i in range(20):
            bars.append(bar(t, 100.0))
            t += timedelta(hours=1)

        # signal at 10:00, future is 12:00 (2 hours later = 2 bars later in this series)
        sig_idx = 10
        fut_idx = 12
        bars[sig_idx] = bar(bars[sig_idx].time, 100.0, i1_buy=1.0, i2_buy=1.0)
        bars[fut_idx] = bar(bars[fut_idx].time, 101.0)

        stats = run_combiner(bars, cfg)
        self.assertEqual(stats.total, 1)
        self.assertEqual(stats.successful, 1)
        self.assertEqual(stats.failed, 0)
        self.assertEqual(stats.events[0].direction, 1)
        self.assertTrue(stats.events[0].success)

    def test_buy_failure_when_future_close_not_higher(self):
        cfg = CombinerConfig(bars_forward=2)
        bars = [bar(datetime(2026, 8, 3, i, 0), 100.0) for i in range(20)]
        bars[10] = bar(bars[10].time, 100.0, i1_buy=1.0, i2_buy=1.0)
        bars[12] = bar(bars[12].time, 100.0)  # equal close = failure
        stats = run_combiner(bars, cfg)
        self.assertEqual(stats.total, 1)
        self.assertEqual(stats.successful, 0)
        self.assertEqual(stats.failed, 1)

    def test_sell_success_when_future_close_lower(self):
        cfg = CombinerConfig(bars_forward=2)
        bars = [bar(datetime(2026, 8, 3, i, 0), 100.0) for i in range(20)]
        bars[10] = bar(bars[10].time, 100.0, i1_sell=1.0, i2_sell=1.0)
        bars[12] = bar(bars[12].time, 98.0)
        stats = run_combiner(bars, cfg)
        self.assertEqual(stats.total, 1)
        self.assertEqual(stats.successful, 1)
        self.assertEqual(stats.events[0].direction, -1)

    def test_sell_failure_when_future_close_not_lower(self):
        cfg = CombinerConfig(bars_forward=2)
        bars = [bar(datetime(2026, 8, 3, i, 0), 100.0) for i in range(20)]
        bars[10] = bar(bars[10].time, 100.0, i1_sell=1.0, i2_sell=1.0)
        bars[12] = bar(bars[12].time, 101.0)
        stats = run_combiner(bars, cfg)
        self.assertEqual(stats.failed, 1)
        self.assertEqual(stats.successful, 0)

    def test_forming_and_too_recent_signals_excluded_from_stats(self):
        cfg = CombinerConfig(bars_forward=2)
        bars = [bar(datetime(2026, 8, 3, i, 0), 100.0 + i) for i in range(20)]
        # last bar = shift 0 forming; shift 1 = last closed; need future_shift >= 1
        # newestAllowedShift = 3, so shift 1 and 2 are not counted
        bars[-1] = bar(bars[-1].time, 120.0, i1_buy=1.0, i2_buy=1.0)  # forming
        bars[-2] = bar(bars[-2].time, 119.0, i1_buy=1.0, i2_buy=1.0)  # shift 1
        bars[-3] = bar(bars[-3].time, 118.0, i1_buy=1.0, i2_buy=1.0)  # shift 2
        bars[-4] = bar(bars[-4].time, 117.0, i1_buy=1.0, i2_buy=1.0)  # shift 3 counted
        stats = run_combiner(bars, cfg)
        self.assertEqual(stats.total, 1)
        drawn = collect_drawn_signals(bars, cfg)
        # forming (shift 0) not drawn; shift 1 and 2 drawn as signals without/with result
        shifts = [e.shift for e in drawn]
        self.assertNotIn(0, shifts)
        self.assertIn(1, shifts)
        self.assertIn(3, shifts)

    def test_weekend_signal_excluded_from_stats(self):
        cfg = CombinerConfig(use_time_filter=True, saturday=False)
        # mix weekday + saturday
        bars = []
        t = datetime(2026, 8, 7, 10, 0)  # Friday
        for i in range(20):
            bars.append(bar(t, 100.0 + i))
            t += timedelta(hours=1)
        # Saturday 10:00 is index around 24 hours later - let's place explicitly
        # Friday 10:00 + 24h = Saturday 10:00
        sat = datetime(2026, 8, 8, 10, 0)
        bars = [bar(datetime(2026, 8, 7, 0, 0) + timedelta(hours=i), 100.0) for i in range(40)]
        # find saturday 10:00
        for i, b in enumerate(bars):
            if b.time == sat:
                bars[i] = bar(sat, 100.0, i1_buy=1.0, i2_buy=1.0)
                if i + 2 < len(bars):
                    bars[i + 2] = bar(bars[i + 2].time, 110.0)
        stats = run_combiner(bars, cfg)
        self.assertEqual(stats.total, 0)

    def test_streaks_oldest_to_newest(self):
        cfg = CombinerConfig(bars_forward=2)
        bars = [bar(datetime(2026, 8, 3, i, 0), 100.0) for i in range(20)]
        # three BUY signals whose outcomes are Win, Win, Loss (oldest first)
        # signal at hour 5 -> future hour 7 close 101 win
        # signal at hour 8 -> future hour 10 close 102 win
        # signal at hour 11 -> future hour 13 close 99 loss
        bars[5] = bar(bars[5].time, 100.0, i1_buy=1.0, i2_buy=1.0)
        bars[7] = bar(bars[7].time, 101.0)
        bars[8] = bar(bars[8].time, 100.0, i1_buy=1.0, i2_buy=1.0)
        bars[10] = bar(bars[10].time, 102.0)
        bars[11] = bar(bars[11].time, 100.0, i1_buy=1.0, i2_buy=1.0)
        bars[13] = bar(bars[13].time, 99.0)

        stats = run_combiner(bars, cfg)
        self.assertEqual(stats.total, 3)
        self.assertEqual(stats.successful, 2)
        self.assertEqual(stats.failed, 1)
        self.assertEqual(stats.max_win_streak, 2)
        self.assertEqual(stats.max_loss_streak, 1)
        self.assertEqual(stats.current_streak_text, "-1 (FAILURE)")
        self.assertAlmostEqual(stats.success_rate, 66.6666, places=2)

    def test_outside_hours_not_counted_even_if_both_indicators_fire(self):
        cfg = CombinerConfig(
            use_time_filter=True,
            start_hour=9,
            start_minute=0,
            end_hour=12,
            end_minute=0,
        )
        bars = [bar(datetime(2026, 8, 3, i, 0), 100.0) for i in range(20)]
        bars[14] = bar(bars[14].time, 100.0, i1_buy=1.0, i2_buy=1.0)  # 14:00 out
        bars[16] = bar(bars[16].time, 110.0)
        stats = run_combiner(bars, cfg)
        self.assertEqual(stats.total, 0)


class RequirementCoverageTests(unittest.TestCase):
    """High-level checklist matching the user's v1 spec."""

    def test_exactly_two_custom_indicator_slots_in_source(self):
        from pathlib import Path

        src = Path(__file__).resolve().parents[1] / "Indicators" / "StrategyCombiner_v1.mq5"
        text = src.read_text(encoding="utf-8")
        self.assertIn("Indicator1_Name", text)
        self.assertIn("Indicator2_Name", text)
        self.assertIn("Indicator1_BuyBuffer", text)
        self.assertIn("Indicator1_SellBuffer", text)
        self.assertIn("Indicator2_BuyBuffer", text)
        self.assertIn("Indicator2_SellBuffer", text)
        self.assertNotIn("iRSI", text)
        self.assertIn("iCustom(_Symbol, _Period, Indicator1_Name)", text)
        self.assertIn("iCustom(_Symbol, _Period, Indicator2_Name)", text)
        self.assertIn("#property indicator_chart_window", text)
        self.assertNotIn("OnTick()", text)

    def test_n_bar_rule_documented_in_source(self):
        from pathlib import Path

        src = Path(__file__).resolve().parents[1] / "Indicators" / "StrategyCombiner_v1.mq5"
        text = src.read_text(encoding="utf-8")
        self.assertIn("close[futureShift] > close[shift]", text)
        self.assertIn("close[futureShift] < close[shift]", text)
        self.assertIn("BarsForward", text)
        self.assertIn("UseIndicator1", text)
        self.assertIn("UseTrendIndicator", text)
        self.assertIn("PLOT_ARROW, 159", text)
        self.assertIn("PLOT_ARROW, 164", text)
        self.assertIn("iMA(_Symbol, _Period, TrendMA_Period", text)
        self.assertIn("UseDayFilter", text)
        self.assertIn("StatsLookbackBars", text)
        self.assertIn("TOTAL PIPS", text)
        self.assertIn("SLOT_MODE_CROSS_SIGNAL", text)
        self.assertIn("UseTrendAngleFilter", text)


class EnableDisableAndTrendTests(unittest.TestCase):
    def test_single_indicator1_buy_when_indicator2_off(self):
        cfg = CombinerConfig(use_indicator1=True, use_indicator2=False)
        b = bar(weekday(), 100, i1_buy=1.0)
        self.assertEqual(get_combined_signal(b, cfg), 1)

    def test_single_indicator2_sell_when_indicator1_off(self):
        cfg = CombinerConfig(use_indicator1=False, use_indicator2=True)
        b = bar(weekday(), 100, i2_sell=1.0)
        self.assertEqual(get_combined_signal(b, cfg), -1)

    def test_both_off_gives_no_signal(self):
        cfg = CombinerConfig(use_indicator1=False, use_indicator2=False)
        b = bar(weekday(), 100, i1_buy=1.0, i2_buy=1.0)
        self.assertEqual(get_combined_signal(b, cfg), 0)

    def test_trend_filters_buy_below_line(self):
        cfg = CombinerConfig(use_trend=True, trend_compare="close")
        ok = bar(weekday(), 110, i1_buy=1.0, i2_buy=1.0, trend=100)
        blocked = bar(weekday(), 90, i1_buy=1.0, i2_buy=1.0, trend=100)
        self.assertEqual(get_final_signal(ok, cfg), 1)
        self.assertEqual(get_final_signal(blocked, cfg), 0)

    def test_trend_filters_sell_above_line(self):
        cfg = CombinerConfig(use_trend=True, trend_compare="close")
        ok = bar(weekday(), 90, i1_sell=1.0, i2_sell=1.0, trend=100)
        blocked = bar(weekday(), 110, i1_sell=1.0, i2_sell=1.0, trend=100)
        self.assertEqual(get_final_signal(ok, cfg), -1)
        self.assertEqual(get_final_signal(blocked, cfg), 0)

    def test_trend_off_does_not_block(self):
        cfg = CombinerConfig(use_trend=False)
        b = bar(weekday(), 90, i1_buy=1.0, i2_buy=1.0, trend=100)
        self.assertEqual(get_final_signal(b, cfg), 1)

    def test_outcome_still_n_bar_after_trend_confirm(self):
        cfg = CombinerConfig(use_trend=True, bars_forward=2)
        bars = [bar(datetime(2026, 8, 3, i, 0), 100.0, trend=95.0) for i in range(20)]
        bars[10] = bar(bars[10].time, 100.0, i1_buy=1.0, i2_buy=1.0, trend=95.0)
        bars[12] = bar(bars[12].time, 101.0, trend=95.0)
        bars[6] = bar(bars[6].time, 80.0, i1_buy=1.0, i2_buy=1.0, trend=95.0)
        bars[8] = bar(bars[8].time, 120.0, trend=95.0)
        stats = run_combiner(bars, cfg)
        self.assertEqual(stats.filtered_by_trend, 1)
        self.assertEqual(stats.total, 1)
        self.assertEqual(stats.successful, 1)

    def test_compare_high_vs_trend(self):
        cfg = CombinerConfig(use_trend=True, trend_compare=TREND_CMP_HIGH)
        b = bar(weekday(), 99, i1_buy=1.0, i2_buy=1.0, high=105, low=98, trend=100)
        self.assertEqual(get_final_signal(b, cfg), 1)

    def test_compare_signal_value(self):
        cfg = CombinerConfig(use_trend=True, trend_compare=TREND_CMP_SIGNAL)
        b = bar(weekday(), 90, i1_buy=110.0, i2_buy=112.0, trend=100)
        self.assertEqual(get_final_signal(b, cfg), 1)
        b2 = bar(weekday(), 120, i1_buy=90.0, i2_buy=91.0, trend=100)
        self.assertEqual(get_final_signal(b2, cfg), 0)


class LookbackPipsCrossAngleTests(unittest.TestCase):
    def test_lookback_limits_counted_signals(self):
        cfg_all = CombinerConfig(bars_forward=2, stats_lookback_bars=0)
        cfg_few = CombinerConfig(bars_forward=2, stats_lookback_bars=4)
        bars = [bar(datetime(2026, 8, 3, i, 0), 100.0 + i) for i in range(20)]
        for idx in (5, 8, 11, 14):
            bars[idx] = bar(bars[idx].time, bars[idx].close, i1_buy=1.0, i2_buy=1.0)
        self.assertGreater(run_combiner(bars, cfg_all).total, run_combiner(bars, cfg_few).total)

    def test_total_and_average_pips_after_n_bars(self):
        cfg = CombinerConfig(bars_forward=2, pip_size=0.0001)
        bars = [bar(datetime(2026, 8, 3, i, 0), 1.1000) for i in range(20)]
        bars[10] = bar(bars[10].time, 1.1000, i1_buy=1.0, i2_buy=1.0)
        bars[12] = bar(bars[12].time, 1.1010)
        stats = run_combiner(bars, cfg)
        self.assertEqual(stats.total, 1)
        self.assertAlmostEqual(stats.total_pips, 10.0, places=4)
        self.assertAlmostEqual(stats.average_pips, 10.0, places=4)

    def test_cross_up_is_buy_when_mode_cross_signal(self):
        from strategy_combiner_logic import get_source_signal_at
        cfg = CombinerConfig(use_indicator1=True, use_indicator2=False, indicator1_mode="cross_signal")
        bars = [bar(datetime(2026, 8, 3, i, 0), 100.0) for i in range(20)]
        bars[9] = bar(bars[9].time, 100.0, i1_buy=1.0, i1_sell=2.0)
        bars[10] = bar(bars[10].time, 100.0, i1_buy=3.0, i1_sell=2.0)
        self.assertEqual(get_source_signal_at(bars, len(bars) - 1 - 10, cfg), 1)

    def test_cross_trend_filters_buy_when_fast_below_slow(self):
        cfg = CombinerConfig(indicator1_mode="buffers", indicator2_mode="cross_trend")
        ok = bar(weekday(), 110, i1_buy=1.0, i2_buy=5.0, i2_sell=1.0)
        blocked = bar(weekday(), 110, i1_buy=1.0, i2_buy=1.0, i2_sell=5.0)
        self.assertEqual(get_final_signal(ok, cfg), 1)
        self.assertEqual(get_final_signal(blocked, cfg), 0)

    def test_angle_neutral_blocks_signal(self):
        from strategy_combiner_logic import is_trend_confirmed_at
        cfg = CombinerConfig(use_trend_angle_filter=True, trend_angle_period=2,
                             trend_angle_buy_min=20, trend_angle_sell_max=-20, pip_size=0.0001)
        bars = [bar(datetime(2026, 8, 3, i, 0), 1.1000, trend=1.1000, i1_buy=1.0, i2_buy=1.0) for i in range(20)]
        self.assertFalse(is_trend_confirmed_at(bars, 5, 1, cfg))


if __name__ == "__main__":
    unittest.main(verbosity=2)
